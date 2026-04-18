output "vpc_id" {
  description = "ID of the VPC created by the networking module"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.storage.bucket_name
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.storage.bucket_arn
}
