variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "aws-infra-template"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "state_key" {
  description = "S3 key for the root-module Terraform state file"
  type        = string
  default     = "root/terraform.tfstate"
}
