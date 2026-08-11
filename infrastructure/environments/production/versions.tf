terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "platform-alex-terraform-state"
    key = "production/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
    encrypt = true
  }
}

provider "aws" {
  region = var.region
}