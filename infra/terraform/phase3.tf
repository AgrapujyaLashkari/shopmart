data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix            = "${var.project_name}-${var.environment}"
  availability_zones     = slice(data.aws_availability_zones.available.names, 0, 2)
  app_repository_name    = "${local.name_prefix}-app"
  ecs_execution_role_arn = var.create_ecs_iam_roles ? aws_iam_role.ecs_execution[0].arn : var.ecs_execution_role_arn
  ecs_task_role_arn      = var.create_ecs_iam_roles ? aws_iam_role.ecs_task[0].arn : var.ecs_task_role_arn
}

resource "random_password" "db_password" {
  length  = 20
  special = false
}

resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

resource "aws_ecr_repository" "app" {
  name                 = local.app_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.app_repository_name
    }
  )
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the most recent 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_vpc" "app" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-vpc"
    }
  )
}

resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-igw"
    }
  )
}

resource "aws_subnet" "public" {
  count = length(local.availability_zones)

  vpc_id                  = aws_vpc.app.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-public-${count.index + 1}"
    }
  )
}

resource "aws_subnet" "private" {
  count = length(local.availability_zones)

  vpc_id            = aws_vpc.app.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-private-${count.index + 1}"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-public-rt"
    }
  )
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.app.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-private-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow HTTP traffic to the ShopSmart load balancer"
  vpc_id      = aws_vpc.app.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb-sg"
    }
  )
}

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Allow HTTP traffic from the load balancer to the ShopSmart app"
  vpc_id      = aws_vpc.app.id

  ingress {
    from_port       = var.app_container_port
    to_port         = var.app_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-app-sg"
    }
  )
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Allow MySQL access from the ShopSmart ECS tasks"
  vpc_id      = aws_vpc.app.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-rds-sg"
    }
  )
}

resource "aws_db_subnet_group" "app" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-db-subnet-group"
    }
  )
}

resource "aws_db_instance" "app" {
  identifier                 = "${local.name_prefix}-mysql"
  engine                     = "mysql"
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  max_allocated_storage      = var.db_max_allocated_storage
  db_name                    = var.mysql_database_name
  username                   = var.mysql_username
  password                   = random_password.db_password.result
  db_subnet_group_name       = aws_db_subnet_group.app.name
  vpc_security_group_ids     = [aws_security_group.rds.id]
  multi_az                   = var.rds_multi_az
  publicly_accessible        = false
  storage_encrypted          = true
  backup_retention_period    = var.rds_backup_retention_days
  skip_final_snapshot        = var.rds_skip_final_snapshot
  deletion_protection        = var.rds_deletion_protection
  apply_immediately          = true
  auto_minor_version_upgrade = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-mysql"
    }
  )
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_iam_role" "ecs_execution" {
  count = var.create_ecs_iam_roles ? 1 : 0

  name = "${local.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  count      = var.create_ecs_iam_roles ? 1 : 0
  role       = aws_iam_role.ecs_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  count = var.create_ecs_iam_roles ? 1 : 0

  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_lb" "app" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )
}

resource "aws_lb_target_group" "app" {
  name        = "${substr(local.name_prefix, 0, 22)}-app"
  port        = var.app_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.app.id

  health_check {
    enabled             = true
    path                = "/api/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200-399"
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_ecs_cluster" "app" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "app" {
  count = var.enable_ecs_deployment ? 1 : 0

  family                   = "${local.name_prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.ecs_task_cpu)
  memory                   = tostring(var.ecs_task_memory)
  execution_role_arn       = local.ecs_execution_role_arn
  task_role_arn            = local.ecs_task_role_arn

  runtime_platform {
    cpu_architecture        = var.ecs_cpu_architecture
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:${var.app_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = var.app_container_port
          hostPort      = var.app_container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = tostring(var.app_container_port) },
        { name = "JWT_SECRET", value = random_password.jwt_secret.result },
        { name = "JWT_EXPIRES_IN", value = "7d" },
        {
          name  = "DATABASE_URL"
          value = "mysql://${var.mysql_username}:${random_password.db_password.result}@${aws_db_instance.app.address}:3306/${var.mysql_database_name}"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:${var.app_container_port}/api/health >/dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 45
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "app"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "app" {
  count = var.enable_ecs_deployment ? 1 : 0

  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app[0].arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.app.id]
    subnets          = aws_subnet.public[*].id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.app_container_port
  }

  depends_on = [
    aws_lb_listener.http
  ]

  tags = local.common_tags
}
