terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.42.0"
    }
  }

  required_version = "~> 1.2"

  #Backend configuration for Terraform state storage in S3
  backend "s3" {
    bucket       = "client-hosting-tfstate-eb6b3ade" # the bucket name
    key          = "infra/terraform.tfstate"         # the path inside the bucket
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.project_name
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}

