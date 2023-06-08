terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.0"
    }
  }
  backend "s3" {
    key    = "aws/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
  profile = var.aws_profile
}

provider "github" {
  version = "2.4.0"
  organization = "eniolastyle"
  token = var.github_Oauthtoken
}
