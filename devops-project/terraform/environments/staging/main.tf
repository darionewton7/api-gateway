provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "payment-gateway-staging-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payment-gateway-staging-terraform-locks"
    encrypt        = true
  }
}

locals {
  project     = "payment-gateway"
  environment = "staging"
  
  tags = {
    Project     = local.project
    Environment = local.environment
    Terraform   = "true"
    ManagedBy   = "DevOps"
  }
}

# Módulo de estado do Terraform
module "terraform_state" {
  source = "../../modules/terraform-state"
  
  project     = local.project
  environment = local.environment
  tags        = local.tags
}

# Módulo VPC
module "vpc" {
  source = "../../modules/vpc"
  
  project     = local.project
  environment = local.environment
  
  vpc_cidr        = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = true  # Para ambiente de staging, usamos apenas um NAT Gateway para reduzir custos
  
  tags = local.tags
}

# Módulo Security Groups
module "security" {
  source = "../../modules/security"
  
  project     = local.project
  environment = local.environment
  
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = module.vpc.vpc_cidr_block
  
  tags = local.tags
}

# Módulo ECS
module "ecs" {
  source = "../../modules/ecs"
  
  project     = local.project
  environment = local.environment
  
  vpc_id               = module.vpc.vpc_id
  private_subnets      = module.vpc.private_subnets
  ecs_security_group_id = module.security.ecs_security_group_id
  
  tags = local.tags
}

# Módulo ALB
module "alb" {
  source = "../../modules/alb"
  
  project     = local.project
  environment = local.environment
  
  vpc_id               = module.vpc.vpc_id
  public_subnets       = module.vpc.public_subnets
  alb_security_group_id = module.security.alb_security_group_id
  
  tags = local.tags
}

# Módulo RDS
module "rds" {
  source = "../../modules/rds"
  
  project     = local.project
  environment = local.environment
  
  vpc_id               = module.vpc.vpc_id
  private_subnets      = module.vpc.private_subnets
  rds_security_group_id = module.security.rds_security_group_id
  
  db_name            = "paymentdb"
  db_username        = "dbadmin"
  db_password        = "StrongPassword123!"  # Em produção, use AWS Secrets Manager ou variáveis de ambiente
  db_instance_class  = "db.t3.small"
  db_allocated_storage = 20
  db_multi_az        = false  # Para staging, desativamos Multi-AZ para reduzir custos
  
  tags = local.tags
}

# Outputs
output "vpc_id" {
  description = "ID da VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "IDs das subnets privadas"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "IDs das subnets públicas"
  value       = module.vpc.public_subnets
}

output "alb_dns_name" {
  description = "DNS name do ALB"
  value       = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS"
  value       = module.ecs.cluster_name
}

output "db_endpoint" {
  description = "Endpoint do RDS"
  value       = module.rds.db_instance_endpoint
}

output "terraform_state_bucket" {
  description = "Bucket S3 para o estado do Terraform"
  value       = module.terraform_state.s3_bucket_id
}
