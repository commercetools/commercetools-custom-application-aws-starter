variable "aws-profile" {
  type        = string
  description = "Name of the aws cli profile used (ex default )"
  default     = "default"
}

variable "aws-region" {
  type        = string
  description = "AWS Region to deploy S3 bucket"
  default     = "us-east-1"
}

variable "website-domain" {
  type        = string
  description = "Domain used for final custom application"
  default     = "custom-app.yourdomain.com"
}

variable "acm_certificate_domain" {
  type        = string
  description = "Domain of the acm certificate that should be used.  It should already exist in aws."
  default     = "*.yourdomain.com"
}

variable "route53-zone-name" {
  type        = string
  description = "Name of the existing route53 hosted zone"
  default     = "yourdomain.com."
}

variable "custom-app-bkt" {
  type        = string
  description = "Name of the bucket for serving the custom application"
  default     = "custom-app-bucket-name"
}

variable "s3_force_destroy" {
  type        = string
  description = "Destroy the s3 bucket inspite of contents in it."
  default     = true
}


