provider "aws" {
  region                   = "region"
  shared_credentials_files = .aws\credentials # Adjust path for Windows
  profile                  = "default"
}

resource "aws_dynamodb_table" "testdb-openmap" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "OpenChargeMap Data Table"
  }
}

resource "aws_s3_bucket" "testbucket-various" {
  bucket = "testbucket-various"
}

resource "aws_lambda_function" "fetch_and_upload" {
  function_name = "fetch_and_upload_to_s3"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "fetch_and_upload_to_s3.lambda_handler"

  filename         = "../../handlers/fetch_and_upload_to_s3.zip"
  source_code_hash = filebase64sha256("../../handlers/fetch_and_upload_to_s3.zip")

  environment {
    variables = {
      S3_BUCKET_NAME        = var.s3_bucket_name
      OPENCHARGEMAP_API_KEY = var.openchargemap_api_key
    }
  }
}

resource "aws_lambda_function" "s3_to_dynamo" {
  function_name = "s3_to_dynamo"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "s3_to_dynamo.lambda_handler"

  filename         = "../../handlers/s3_to_dynamo.zip"
  source_code_hash = filebase64sha256("../../handlers/s3_to_dynamo.zip")

  environment {
    variables = {
      S3_BUCKET_NAME      = var.s3_bucket_name
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
    }
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "Policy for Lambda to access S3 and DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_cloudwatch_event_rule" "fetch_and_upload_schedule" {
  name                = "fetch_and_upload_schedule"
  description         = "Trigger fetch_and_upload Lambda every 3 hours"
  schedule_expression = "rate(3 hours)"
}

resource "aws_cloudwatch_event_target" "fetch_and_upload_target" {
  rule      = aws_cloudwatch_event_rule.fetch_and_upload_schedule.name
  target_id = "fetch_and_upload_target"
  arn       = aws_lambda_function.fetch_and_upload.arn
}

resource "aws_s3_bucket_notification" "s3_trigger" {
  bucket = aws_s3_bucket.testbucket-various.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_to_dynamo.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_trigger]
}

resource "aws_lambda_permission" "allow_s3_trigger" {
  statement_id  = "AllowS3Trigger"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_to_dynamo.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.testbucket-various.arn
}

resource "aws_lambda_permission" "allow_fetch_and_upload_schedule" {
  statement_id  = "AllowEventBridgeFetchAndUpload"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_and_upload.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.fetch_and_upload_schedule.arn
}

variable "aws_access_key_id" {
  description = "The AWS access key ID"
  type        = string
}

variable "aws_secret_access_key" {
  description = "The AWS secret access key"
  type        = string
}

variable "aws_region" {
  description = "The AWS region"
  type        = string
}

variable "openchargemap_api_key" {
  description = "The API key for OpenChargeMap"
  type        = string
}

data "aws_caller_identity" "current" {}
