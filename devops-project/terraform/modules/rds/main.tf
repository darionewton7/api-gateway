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

variable "private_subnets" {
  description = "Lista de IDs das subnets privadas"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "ID do security group para o RDS"
  type        = string
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "app"
}

variable "db_username" {
  description = "Nome de usuário do banco de dados"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Senha do banco de dados"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Classe da instância do RDS"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "Armazenamento alocado para o RDS (GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Armazenamento máximo alocado para o RDS (GB)"
  type        = number
  default     = 100
}

variable "db_backup_retention_period" {
  description = "Período de retenção de backups (dias)"
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Habilitar Multi-AZ para o RDS"
  type        = bool
  default     = true
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

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = var.private_subnets
  
  tags = local.tags
}

resource "aws_db_parameter_group" "this" {
  name   = "${local.name}-db-parameter-group"
  family = "postgres14"
  
  parameter {
    name  = "log_connections"
    value = "1"
  }
  
  parameter {
    name  = "log_disconnections"
    value = "1"
  }
  
  tags = local.tags
}

resource "aws_db_instance" "this" {
  identifier             = "${local.name}-db"
  engine                 = "postgres"
  engine_version         = "14.7"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = var.db_max_allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  port                   = 5432
  vpc_security_group_ids = [var.rds_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  skip_final_snapshot    = var.environment == "production" ? false : true
  final_snapshot_identifier = var.environment == "production" ? "${local.name}-db-final-snapshot" : null
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:30-Mon:05:30"
  multi_az                = var.environment == "production" ? var.db_multi_az : false
  deletion_protection     = var.environment == "production" ? true : false
  
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  
  lifecycle {
    prevent_destroy = var.environment == "production" ? true : false
  }
  
  tags = local.tags
}

output "db_instance_id" {
  description = "ID da instância do RDS"
  value       = aws_db_instance.this.id
}

output "db_instance_address" {
  description = "Endereço da instância do RDS"
  value       = aws_db_instance.this.address
}

output "db_instance_endpoint" {
  description = "Endpoint de conexão da instância do RDS"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_name" {
  description = "Nome do banco de dados"
  value       = aws_db_instance.this.db_name
}

output "db_instance_username" {
  description = "Nome de usuário do banco de dados"
  value       = aws_db_instance.this.username
}

output "db_instance_port" {
  description = "Porta do banco de dados"
  value       = aws_db_instance.this.port
}
