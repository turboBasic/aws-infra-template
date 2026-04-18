terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.40"
    }
  }

  # Bootstrap uses the local backend — its state is managed manually and
  # backed up to the `aws_s3_bucket.bootstrap_state` bucket created here.
}

provider "aws" {
  region = var.aws_region
}
