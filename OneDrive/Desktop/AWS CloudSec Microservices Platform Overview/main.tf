terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # These values must be provided via command line or environment variables
    # bucket         = "terraform-state-bucket"
    # key            = "aws-cloudsec-microservices/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-locks"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "AWS-CloudSec-Microservices"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name to be used as prefix for resources"
  type        = string
  default     = "cloudsec"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  environment  = var.environment
  project_name = var.project_name
  aws_region   = var.aws_region
}

# Security Module
module "security" {
  source = "./modules/security"
  
  environment  = var.environment
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  
  depends_on = [module.vpc]
}

# EKS Module
module "eks" {
  source = "./modules/eks"
  
  environment       = var.environment
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  depends_on = [module.vpc, module.security]
}

# RDS Module
module "rds" {
  source = "./modules/rds"
  
  environment       = var.environment
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id = module.security.db_security_group_id
  
  depends_on = [module.vpc, module.security]
}

# DynamoDB Module
module "dynamodb" {
  source = "./modules/dynamodb"
  
  environment  = var.environment
  project_name = var.project_name
}

# ElastiCache Module
module "elasticache" {
  source = "./modules/elasticache"
  
  environment       = var.environment
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id = module.security.cache_security_group_id
  
  depends_on = [module.vpc, module.security]
}

# Cognito Module
module "cognito" {
  source = "./modules/cognito"
  
  environment  = var.environment
  project_name = var.project_name
}

# S3 Module
module "s3" {
  source = "./modules/s3"
  
  environment  = var.environment
  project_name = var.project_name
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api-gateway"
  
  environment  = var.environment
  project_name = var.project_name
  cognito_user_pool_id = module.cognito.user_pool_id
  
  depends_on = [module.cognito]
}

# Vault Module
module "vault" {
  source = "./modules/vault"
  
  environment       = var.environment
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id = module.security.vault_security_group_id
  
  depends_on = [module.vpc, module.security]
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  
  environment       = var.environment
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  depends_on = [module.vpc]
}

# Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "The endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = module.cognito.user_pool_id
}

output "api_gateway_url" {
  description = "The URL of the API Gateway"
  value       = module.api_gateway.api_gateway_url
}

output "frontend_bucket_name" {
  description = "The name of the S3 bucket for frontend assets"
  value       = module.s3.frontend_bucket_name
}

output "vault_endpoint" {
  description = "The endpoint for HashiCorp Vault"
  value       = module.vault.vault_endpoint
}
