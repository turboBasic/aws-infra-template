variable "bucket_name" {
  description = "Base name of the S3 bucket — the AWS account ID is appended for global uniqueness"
  type        = string

  validation {
    condition = (
      length(var.bucket_name) >= 3 &&
      length(var.bucket_name) <= 50 &&
      can(regex("^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$", var.bucket_name))
    )
    error_message = "bucket_name must be 3-50 characters, use lowercase letters/numbers/hyphens, and start/end with a letter or number. The 50-char limit reserves room for '-<12-digit-account-id>'."
  }
}

variable "name_prefix" {
  description = "Prefix for Name tag"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to the bucket"
  type        = map(string)
  default     = {}
}
