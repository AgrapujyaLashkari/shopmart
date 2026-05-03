variable "aws_region" {
  description = "AWS region where the S3 bucket will be created."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used for tagging AWS resources."
  type        = string
  default     = "shopsmart"
}

variable "environment" {
  description = "Environment name used for tagging AWS resources."
  type        = string
  default     = "dev"
}

variable "bucket_name_prefix" {
  description = "Prefix for the S3 bucket name. Terraform appends a unique suffix automatically."
  type        = string
  default     = "shopsmart-phase2"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,50}$", var.bucket_name_prefix))
    error_message = "bucket_name_prefix must be 3-50 characters and use only lowercase letters, numbers, or hyphens."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC created for ECS deployment."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDR blocks used by the ALB and ECS service."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "public_subnet_cidrs must contain exactly two subnet CIDR blocks."
  }
}

variable "private_subnet_cidrs" {
  description = "Two private subnet CIDR blocks used by the RDS subnet group."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "private_subnet_cidrs must contain exactly two subnet CIDR blocks."
  }
}

variable "enable_ecs_deployment" {
  description = "Set to true after Docker images have been pushed to ECR so Terraform can create the ECS task definition and service."
  type        = bool
  default     = false
}

variable "create_ecs_iam_roles" {
  description = "Set to true only when your AWS identity is allowed to create IAM roles for ECS. Leave false in restricted lab accounts and provide existing role ARNs instead."
  type        = bool
  default     = false
}

variable "ecs_execution_role_arn" {
  description = "Existing IAM role ARN for ECS task execution. Required when create_ecs_iam_roles is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_ecs_iam_roles || var.ecs_execution_role_arn != null
    error_message = "ecs_execution_role_arn must be provided when create_ecs_iam_roles is false."
  }
}

variable "ecs_task_role_arn" {
  description = "Existing IAM role ARN for the ECS task. Required when create_ecs_iam_roles is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_ecs_iam_roles || var.ecs_task_role_arn != null
    error_message = "ecs_task_role_arn must be provided when create_ecs_iam_roles is false."
  }
}

variable "app_image_tag" {
  description = "Docker image tag to deploy for the root application ECR repository."
  type        = string
  default     = "latest"
}

variable "app_container_port" {
  description = "Port exposed by the combined application container."
  type        = number
  default     = 5001
}

variable "ecs_task_cpu" {
  description = "CPU units allocated to the ECS task."
  type        = number
  default     = 1024
}

variable "ecs_task_memory" {
  description = "Memory in MiB allocated to the ECS task."
  type        = number
  default     = 2048
}

variable "ecs_cpu_architecture" {
  description = "CPU architecture for the ECS Fargate task. Must match the architecture of the Docker image pushed to ECR."
  type        = string
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.ecs_cpu_architecture)
    error_message = "ecs_cpu_architecture must be either ARM64 or X86_64."
  }
}

variable "ecs_desired_count" {
  description = "Desired number of running ECS tasks."
  type        = number
  default     = 1
}

variable "mysql_image" {
  description = "MySQL container image used inside the ECS task."
  type        = string
  default     = "mysql:8.4"
}

variable "mysql_database_name" {
  description = "Database name used locally and on RDS."
  type        = string
  default     = "shopsmart"
}

variable "mysql_username" {
  description = "Application database username used locally and on RDS."
  type        = string
  default     = "shopsmart"
}

variable "db_instance_class" {
  description = "RDS instance class for the production MySQL database."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial storage allocation in GiB for the RDS instance."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum autoscaled storage in GiB for the RDS instance."
  type        = number
  default     = 100
}

variable "rds_multi_az" {
  description = "Whether to enable Multi-AZ deployment for RDS."
  type        = bool
  default     = false
}

variable "rds_backup_retention_days" {
  description = "Number of automated backup retention days for RDS."
  type        = number
  default     = 7
}

variable "rds_skip_final_snapshot" {
  description = "Skip the final snapshot when destroying the RDS instance."
  type        = bool
  default     = true
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection for the RDS instance."
  type        = bool
  default     = false
}
