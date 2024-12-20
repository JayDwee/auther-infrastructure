terraform {
  cloud {
    organization = "JayDwee"

    workspaces {
      project = "auther"
      tags = ["source:github.com/jaydwee/auther-infrastructure"]
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.3.0"
}

# Configure the AWS Provider
provider "aws" {}

module "s3" {
  source = "./modules/data/s3"
  deployment_env = var.deployment_env
}

module "lambda" {
  source         = "./modules/compute/lambda"
  deployment_env = var.deployment_env
}

module "api" {
  source = "./modules/api/api-gateway"
  deployment_env = var.deployment_env
  domain_name = var.domain_name
  s3_bucket_name = module.s3.s3_bucket_name
  lambda_function_invoke_arn = module.lambda.lambda_function_invoke_arn
  lambda_function_name = module.lambda.lambda_function_name
}

module "dynamodb" {
  source = "./modules/data/dynamodb"
  deployment_env = var.deployment_env
}