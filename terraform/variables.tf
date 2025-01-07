variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "eu-central-1"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones to deploy resources"
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.cidr_block))
    error_message = "The provided value is not a valid CIDR block."
  }
}

variable "domain_name" {
  type        = string
  description = "The domain name to use for the Route53 record"
  default     = "theforgotten.link"
}

variable "db_username" {
  type        = string
  description = "Database username"
  default     = "postgres"
}

variable "sherpany_db_name" {
  type        = string
  description = "Sherpany database name"
  default     = "sherpany"
}

variable "sherpany_db_user" {
  type        = string
  description = "Sherpany database user"
  default     = "sherpany"
}

variable "rds_instance_type" {
  type        = string
  description = "RDS instance size"
  default     = "db.t4g.micro"
}

variable "ec2_instance_type" {
  type        = string
  description = "EC2 instance size for Grafana Agent"
  default     = "t3.micro"
}

variable "prometheus_endpoint" {
  type        = string
  description = "Remote write endpoint for Prometheus metrics"
  default     = ""
}

variable "k8s-endpoint" {
  type        = string
  description = "Kubernetes server IP endpoint"
  default     = "https://74.220.26.248:6443"
}

