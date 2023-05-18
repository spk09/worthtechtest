terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  backend "s3" {
    bucket         = "terraformbucket-klam-test"
    key            = "worth_tech_test/key"
    region         = "eu-west-1"
    dynamodb_table = "terraformdydbtable-klam-test"
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-west-1"
}
