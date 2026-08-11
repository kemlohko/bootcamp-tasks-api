output "endpoint" {
  value = aws_db_instance.taskly.address
}

output "port" {
  value = aws_db_instance.taskly.port
}

output "database_name" {
  value = aws_db_instance.taskly.db_name
}

output "master_user_secret_arn" {
  value = aws_db_instance.taskly.master_user_secret[0].secret_arn  # Secrets Manager ARN for the auto-generated password
}