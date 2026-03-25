variable "artifacts_bucket_prefix" {
  description = "Prefix for the artifacts S3 bucket"
  type        = string
}

variable "frontend_bucket_prefix" {
  description = "Prefix for the frontend S3 bucket"
  type        = string
}

variable "reports_expiry_days" {
  description = "Lifecycle expiry days for reports/ prefix"
  type        = number
}
