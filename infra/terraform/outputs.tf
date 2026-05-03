output "s3_bucket_name" {
  description = "Provisioned S3 bucket name."
  value       = aws_s3_bucket.app_bucket.bucket
}

output "s3_bucket_arn" {
  description = "Provisioned S3 bucket ARN."
  value       = aws_s3_bucket.app_bucket.arn
}

output "aws_region" {
  description = "AWS region used for provisioning."
  value       = var.aws_region
}

output "app_ecr_repository_url" {
  description = "Application ECR repository URL."
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name for ShopSmart."
  value       = aws_ecs_cluster.app.name
}

output "ecs_service_name" {
  description = "ECS service name when deployment is enabled."
  value       = try(aws_ecs_service.app[0].name, null)
}

output "alb_dns_name" {
  description = "Public DNS name of the application load balancer."
  value       = aws_lb.app.dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint hostname for the ShopSmart database."
  value       = aws_db_instance.app.address
}

output "rds_database_name" {
  description = "RDS database name used by the application."
  value       = aws_db_instance.app.db_name
}

output "rds_username" {
  description = "RDS username used by the application."
  value       = aws_db_instance.app.username
}

output "deploy_app_next_step" {
  description = "Reminder for the manual Phase 3 workflow."
  value       = var.enable_ecs_deployment ? "ECS service is enabled. Verify the ECS service, ALB health, and RDS connectivity." : "RDS, networking, and ECR can be provisioned now. Push the root application image to ECR, then re-run terraform apply with enable_ecs_deployment=true."
}
