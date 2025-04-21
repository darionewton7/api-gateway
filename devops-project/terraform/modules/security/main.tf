variable "project" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (staging ou production)"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
}

variable "tags" {
  description = "Tags adicionais para recursos"
  type        = map(string)
  default     = {}
}

locals {
  name = "${var.project}-${var.environment}"
  
  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Terraform   = "true"
    },
    var.tags
  )
}

# Security Group para ALB
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Security group para o Application Load Balancer"
  vpc_id      = var.vpc_id
  
  ingress {
    description = "HTTP de qualquer lugar"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTPS de qualquer lugar"
    from_port   = 443
    to_port     = 443
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
    {
      Name = "${local.name}-alb-sg"
    },
    local.tags
  )
}

# Security Group para ECS/Fargate
resource "aws_security_group" "ecs" {
  name        = "${local.name}-ecs-sg"
  description = "Security group para os serviços ECS/Fargate"
  vpc_id      = var.vpc_id
  
  ingress {
    description     = "Tráfego do ALB"
    from_port       = 0
    to_port         = 65535
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
    {
      Name = "${local.name}-ecs-sg"
    },
    local.tags
  )
}

# Security Group para RDS
resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "Security group para o RDS"
  vpc_id      = var.vpc_id
  
  ingress {
    description     = "Acesso ao banco de dados a partir dos serviços ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(
    {
      Name = "${local.name}-rds-sg"
    },
    local.tags
  )
}

# Security Group para Lambda
resource "aws_security_group" "lambda" {
  name        = "${local.name}-lambda-sg"
  description = "Security group para funções Lambda"
  vpc_id      = var.vpc_id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(
    {
      Name = "${local.name}-lambda-sg"
    },
    local.tags
  )
}

output "alb_security_group_id" {
  description = "ID do security group do ALB"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID do security group do ECS"
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "ID do security group do RDS"
  value       = aws_security_group.rds.id
}

output "lambda_security_group_id" {
  description = "ID do security group do Lambda"
  value       = aws_security_group.lambda.id
}
