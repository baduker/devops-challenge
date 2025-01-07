terraform {

  cloud {
    organization = "NoobSystems"
    workspaces {
      name = "sherpany-devops-challange"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.77"
    }
  }

  required_version = ">= 1.9.8"
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Owner       = "NoobSystems"
      Project     = "Sherpany"
      Environment = "Challenge"
    }
  }
}
