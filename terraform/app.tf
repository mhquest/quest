resource "aws_ecr_repository" "quest" {
  name = "${var.environment}-${var.name}-app"
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.quest.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 100 images"
      action = {
        type = "expire"
      }
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 100
      }
    }]
  })
}

resource "aws_cloudwatch_log_group" "example" {
  name = "/ecs/${var.environment}-${var.name}-app"
}

resource "aws_ecs_cluster" "quest" {
  name = "${var.environment}-${var.name}-app"
}

resource "aws_security_group" "quest_alb" {
  name   = "${var.environment}-${var.name}-app-alb"
  vpc_id = module.vpc.vpc_attributes.id

  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name   = "${var.environment}-${var.name}-task-sg"
  vpc_id = module.vpc.vpc_attributes.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.quest_alb.id]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 0
    to_port          = 65535
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_ecs_task_definition" "quest" {
  family                   = "${var.environment}-${var.name}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
    name      = "${var.environment}-${var.name}-container"
    image     = "${var.environment}-${var.name}-app:latest"
    essential = true
    portMappings = [{
      protocol      = "tcp"
      containerPort = 3000
      hostPort      = 3000
    }]
  }])
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.environment}-${var.name}-ecsTaskRole"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.environment}-${var.name}-ecsTaskExecutionRole"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_policy" "app_policy" {
  name        = "${var.environment}_${var.name}_AppSecretsPolicy"
  path        = "/"
  description = "App secrets policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Effect   = "Allow"
        Resource = "*" // This would be filted down to tags or something IRL
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "app_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.app_policy.arn
}

resource "aws_ecs_service" "main" {
  name                               = "${var.environment}-${var.name}-service"
  cluster                            = aws_ecs_cluster.quest.id
  task_definition                    = aws_ecs_task_definition.quest.arn
  desired_count                      = 2
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = [for _, value in module.vpc.private_subnet_attributes_by_az : value.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.quest.arn
    container_name   = "${var.environment}-${var.name}-container"
    container_port   = 3000
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_lb" "quest" {
  name               = "${var.environment}-${var.name}-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.quest_alb.id]
  subnets            = [for _, value in module.vpc.public_subnet_attributes_by_az : value.id]

  enable_deletion_protection = false
}

resource "aws_alb_target_group" "quest" {
  name        = "${var.environment}-${var.name}-app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_attributes.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/ping"
    unhealthy_threshold = "2"
  }

  depends_on = [
    aws_lb.quest,
  ]
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.quest.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.quest.id
    type             = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.quest.id
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.ssl_certificate.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    target_group_arn = aws_alb_target_group.quest.id
    type             = "forward"
  }
}

resource "aws_secretsmanager_secret" "secret_word" {
  name = "${var.environment}/${var.name}-app/SECRET_WORD"
}
