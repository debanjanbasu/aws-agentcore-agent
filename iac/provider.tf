terraform {
  required_version = ">= 1.0"



  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.20.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.65.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

provider "awscc" {
  region = var.aws_region
}

provider "azuread" {
  # Configure via environment variables:
  # export ARM_TENANT_ID="your-tenant-id"
  # export ARM_CLIENT_ID="your-client-id"
  # export ARM_CLIENT_SECRET="your-client-secret"
  #
  # Or use Azure CLI authentication:
  # az login
}