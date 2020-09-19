
provider "aws" {
  region = var.aws_region
  profile = "stage"
}

terraform {
  backend "s3" {
    bucket = "a2i-terraform-state-stage"
    key    = "tfstate"
    region = "eu-west-1"
    profile = "stage"
    dynamodb_table = "a2i-terraform-locktable-stage"
  }
}

data "aws_caller_identity" "current" {}
