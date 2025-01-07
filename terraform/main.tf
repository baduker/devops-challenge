# ------------------------------------------------------------------------------
# Networking Resources
# ------------------------------------------------------------------------------

# A dedicated VPC for the Sherpany DevOps Challenge infrastructure
resource "aws_vpc" "sherpany_main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "sherpany-main-vpc"
  }
}

# We need two public subnets in different availability zones for high availability
# This is forced by the RDS instance, which requires a subnet group with
# at least two subnets.
resource "aws_subnet" "sherpany_public" {
  for_each = tomap({ for idx, az in var.availability_zones : az => idx })

  vpc_id                  = aws_vpc.sherpany_main.id
  cidr_block              = cidrsubnet(aws_vpc.sherpany_main.cidr_block, 4, each.value) # Unique netnum for each AZ
  map_public_ip_on_launch = true
  availability_zone       = each.key

  tags = {
    Name = "sherpany-public-subnet-${each.key}"
  }
}

# Create an Internet Gateway to allow the VPC to connect to the internet
resource "aws_internet_gateway" "sherpany_igw" {
  vpc_id = aws_vpc.sherpany_main.id

  tags = {
    Name = "sherpany-igw"
  }
}

# Create a Route Table for the public subnets to route traffic to the IG
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.sherpany_main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sherpany_igw.id
  }

  tags = {
    Name = "sherpany-public-rt"
  }
}

# Associate the public route table with the public subnets
resource "aws_route_table_association" "public_subnet_assoc" {
  for_each = aws_subnet.sherpany_public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# RDS Instance
# ------------------------------------------------------------------------------

# Create a security group for the RDS instance (Postgres)
# Make sure to allow traffic from the K8s cluster
# and from my IP for troubleshooting :-)
resource "aws_security_group" "rds_sg" {
  name        = "sherpany-rds-sg"
  description = "Allow inbound Postgres"
  vpc_id      = aws_vpc.sherpany_main.id

  ingress {
    description = "Postgres"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # My IP for troubleshooting
    cidr_blocks = ["89.64.17.122/32"]
  }

  ingress {
    description = "Sherpany K8s cluster"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["74.220.0.0/16"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sherpany-rds-sg"
  }
}

# Create a subnet group for the RDS instance using the public subnets
resource "aws_db_subnet_group" "sherpany_db_sg" {
  name        = "sherpany-public-db-subnet-group"
  description = "Subnet group for Sherpany public RDS"
  subnet_ids  = values(aws_subnet.sherpany_public)[*].id

  tags = {
    Name = "sherpany-public-db-subnet-group"
  }
}

# Note: This resource generates a random password for the RDS Admin user
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$*+-=?"
}

# Store the generated password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password_secret" {
  name        = "db-password"
  description = "Stores the generated RDS DB password for the Sherpany DB"
  tags = {
    Name = "sherpany-db-password"
  }
}

# Store the generated password in the secret version (the actual secret)
resource "aws_secretsmanager_secret_version" "db_password_secret_version" {
  secret_id     = aws_secretsmanager_secret.db_password_secret.id
  secret_string = random_password.db_password.result
}

# Create the RDS instance (Postgres)
resource "aws_db_instance" "sherpany_rds" {
  identifier             = "my-postgres-rds"
  allocated_storage      = 20
  max_allocated_storage  = 100
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = var.rds_instance_type
  username               = var.db_username
  password               = random_password.db_password.result
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.sherpany_db_sg.name

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "sherpany-rds-postgres"
  }
}

# Add a nice Route53 record for the RDS instance instead of using the
# default AWS endpoint
resource "aws_route53_record" "db_endpoint" {
  zone_id = data.terraform_remote_state.noob-systems.outputs.hosted_zone_id
  name    = "sherpany-db.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_db_instance.sherpany_rds.address]
}

# This is the RDS user password that the application will use to connect to the DB
resource "random_password" "sherpany_db_user_password" {
  length           = 16
  special          = true
  override_special = "!#$*+-=?"
}

# Store the user generated password along with other DB evns in AWS Secrets Manager
resource "aws_secretsmanager_secret" "sherpany_db_envs" {
  name        = "sherpany-db-envs"
  description = "Stores the generated RDS DB password for the Sherpany DB and other environment variables"
  tags = {
    Name = "sherpany-db-envs"
  }
}

# This is the actual secret version that contains the DB user password
# and other envs that the application will use to connect to the DB
resource "aws_secretsmanager_secret_version" "sherpany_db_envs_version" {
  secret_id = aws_secretsmanager_secret.sherpany_db_envs.id
  secret_string = jsonencode(
    {
      DB_PASSWORD = random_password.sherpany_db_user_password.result
      DB_HOST     = aws_route53_record.db_endpoint.fqdn
      DB_NAME     = var.sherpany_db_name
      DB_USER     = var.sherpany_db_user
    }
  )
}

# ------------------------------------------------------------------------------
# Grafana Agent Instance
# ------------------------------------------------------------------------------

# Let's get the latest Debian AMI for the Grafana Agent instance
data "aws_ami" "debian" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]

}

# Generate a TLS key pair for the Grafana Agent instance
resource "tls_private_key" "grafana_agent_tls_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create an SSH key pair for the Grafana Agent instance
resource "aws_key_pair" "grafana_agent_key" {
  public_key = tls_private_key.grafana_agent_tls_key.public_key_openssh
  key_name   = "sherpany-grafana-agent-key"
}

# The actual Grafana Agent instance
resource "aws_instance" "grafana_agent" {
  ami                         = data.aws_ami.debian.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.sherpany_public[sort(keys(aws_subnet.sherpany_public))[0]].id
  associate_public_ip_address = true
  key_name = aws_key_pair.grafana_agent_key.key_name

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y wget curl unzip

    # Install Grafana Agent
    wget https://github.com/grafana/agent/releases/latest/download/agent-linux-amd64.zip
    unzip agent-linux-amd64.zip -d /usr/local/bin/
    chmod +x /usr/local/bin/agent

    # Create Grafana Agent config file
    cat <<EOL > /etc/agent-config.yaml
    server:
      log_level: info

    metrics:
      configs:
        - name: node_metrics
          scrape_configs:
            - job_name: "node"
              static_configs:
                - targets: ["localhost:9100"]
    remote_write:
      - url: "http://bfed616e-6008-4a7b-a6bb-d505e3573434.k8s.civo.com:30080/api/v1/write"
    EOL

    # Start Grafana Agent as a systemd service
    cat <<EOL > /etc/systemd/system/grafana-agent.service
    [Unit]
    Description=Grafana Agent
    After=network.target

    [Service]
    ExecStart=/usr/local/bin/agent --config.file=/etc/agent-config.yaml
    Restart=always

    [Install]
    WantedBy=multi-user.target
    EOL

    systemctl daemon-reload
    systemctl start grafana-agent
    systemctl enable grafana-agent
  EOF

  tags = {
    Name = "sherpany-grafana-agent-node"
  }

  vpc_security_group_ids = [aws_security_group.grafana_agent_sg.id]
}

# A dedicated security group for the Grafana Agent instance that sits
# in the same VPC as the RDS instance; otherwise it won't work
resource "aws_security_group" "grafana_agent_sg" {
  vpc_id = aws_vpc.sherpany_main.id
  name_prefix = "sherpany-grafana-agent-sg"

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    # My IP for troubleshooting
    cidr_blocks = ["89.64.17.122/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
