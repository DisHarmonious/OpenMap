variable "region" {
  description = "AWS region"
  default     = "region"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  default     = "bucket"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  default     = "table"
}
