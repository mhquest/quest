terraform {
    required_version = "~> 1.4"

  required_providers {
    aws = "~> 4"
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 0.43.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "= 2.2.3"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Name                     = var.name
      Environment              = var.environment
    }
  }
}

provider "awscc" {
  region = var.region
  profile = var.profile
}
