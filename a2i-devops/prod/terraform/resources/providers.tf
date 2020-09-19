provider "aws" {
  region = var.aws_region
  profile = "prod"
}

terraform {
  backend "s3" {
    bucket = "a2i-terraform-state-prod"
    key    = "tfstate"
    region = "eu-west-1"
    profile = "prod"
    dynamodb_table = "a2i-terraform-locktable-prod"
  }
}

data "aws_caller_identity" "current" {}
