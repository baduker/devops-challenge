output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.sherpany_rds.endpoint
}

output "db_route53_record" {
  description = "Route53 DB record"
  value       = aws_route53_record.db_endpoint.fqdn
}

output "grafana_agent_instance_id" {
  value = aws_instance.grafana_agent.id
}

output "grafana_agent_key" {
  value = tls_private_key.grafana_agent_tls_key.private_key_pem
  sensitive = true
}
