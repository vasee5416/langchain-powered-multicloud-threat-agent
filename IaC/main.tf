terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.66.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "me" {}
data "aws_region" "current" {}

locals {
  suffix = substr(replace(data.aws_caller_identity.me.account_id, "/[^0-9]/", ""), -6, 6)
  name   = "${var.project}-${local.suffix}"
  tags   = merge(var.tags, { project = var.project })
}

# -----------------------------
# S3: Logs bucket (GuardDuty export) + KB-ish drop bucket
# -----------------------------
resource "aws_s3_bucket" "logs" {
  bucket        = "${local.name}-gd-logs"
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

# Bucket where Lambda will drop JSONL summaries suitable for later RAG/KBs
resource "aws_s3_bucket" "kb_data" {
  bucket        = "${local.name}-kb-data"
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_public_access_block" "kb_data" {
  bucket                  = aws_s3_bucket.kb_data.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

# -----------------------------
# KMS key (GuardDuty requires KMS for S3 findings export)
# -----------------------------
resource "aws_kms_key" "gd" {
  description             = "KMS for GuardDuty S3 export"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = local.tags
}

resource "aws_kms_alias" "gd" {
  name          = "alias/${local.name}-gd"
  target_key_id = aws_kms_key.gd.key_id
}

# Default bucket encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.gd.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Grant GuardDuty service permission to write to the S3 logs bucket
data "aws_iam_policy_document" "logs_policy" {
  statement {
    sid = "AllowGuardDutyToGetBucketLocation"
    actions   = ["s3:GetBucketLocation"]
    resources = [aws_s3_bucket.logs.arn]
    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }
  }

  statement {
    sid = "AllowGuardDutyToWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.gd.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs_policy.json
}

# KMS policy additions so GuardDuty can use the key
data "aws_iam_policy_document" "kms" {
  statement {
    sid = "AllowGuardDutyUseOfKey"
    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key_policy" "gd_attach" {
  key_id = aws_kms_key.gd.id
  policy = data.aws_iam_policy_document.kms.json
}

# -----------------------------
# GuardDuty detector + S3 publishing destination
# -----------------------------
resource "aws_guardduty_detector" "this" {
  enable                       = true
  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs { enable = true }
    }
    malware_protection {
      scan_ec2_instance_with_findings { ebs_volumes = true }
    }
  }
  tags = local.tags
}

resource "aws_guardduty_publishing_destination" "s3" {
  detector_id      = aws_guardduty_detector.this.id
  destination_arn  = aws_s3_bucket.logs.arn
  kms_key_arn      = aws_kms_key.gd.arn
  destination_type = "S3"
}

# -----------------------------
# Lambda: stream GuardDuty findings events -> summarize with Bedrock -> drop JSONL into kb_data S3
# -----------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/handler.zip"
}

resource "aws_iam_role" "lambda_role" {
  name               = "${local.name}-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = local.tags
}

resource "aws_iam_policy" "lambda_policy" {
  name   = "${local.name}-lambda-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # logs
      { Effect = "Allow", Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], Resource = "*" },
      # write summaries to kb_data
      { Effect = "Allow", Action = ["s3:PutObject","s3:AbortMultipartUpload","s3:ListBucketMultipartUploads"], Resource = [
          aws_s3_bucket.kb_data.arn, "${aws_s3_bucket.kb_data.arn}/*"
      ]},
      # invoke bedrock
      { Effect = "Allow", Action = ["bedrock:InvokeModel","bedrock:InvokeModelWithResponseStream"], Resource = "*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "gd_processor" {
  function_name = "${local.name}-gd-proc"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  filename      = data.archive_file.lambda_zip.output_path
  timeout       = 30
  environment {
    variables = {
      KB_BUCKET        = aws_s3_bucket.kb_data.bucket
      KB_PREFIX        = "gd_summaries/"
      BEDROCK_MODEL_ID = var.bedrock_model_id
      AWS_REGION       = var.region
    }
  }
  tags = local.tags
}

# EventBridge: forward GuardDuty "Finding" events to Lambda
resource "aws_cloudwatch_event_rule" "gd_findings" {
  name          = "${local.name}-gd-findings"
  description   = "Route GuardDuty Finding events to Lambda for Bedrock summarization"
  event_pattern = jsonencode({
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"]
  })
  tags = local.tags
}

resource "aws_cloudwatch_event_target" "gd_to_lambda" {
  rule      = aws_cloudwatch_event_rule.gd_findings.name
  target_id = "lambda"
  arn       = aws_lambda_function.gd_processor.arn
}

resource "aws_lambda_permission" "events_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gd_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.gd_findings.arn
}

# -----------------------------
# SageMaker: simple Notebook Instance (quick start)
# -----------------------------
resource "aws_iam_role" "sagemaker_exec" {
  name               = "${local.name}-sagemaker-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "sagemaker.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = local.tags
}

# Grant SageMaker broad access for prototyping + Bedrock invocation + read the logs bucket
resource "aws_iam_role_policy_attachment" "sm_managed" {
  role       = aws_iam_role.sagemaker_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_policy" "sm_bedrock_s3" {
  name   = "${local.name}-sm-bedrock-s3"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["bedrock:InvokeModel","bedrock:InvokeModelWithResponseStream"], Resource = "*" },
      { Effect = "Allow", Action = ["s3:GetObject","s3:ListBucket"], Resource = [
        aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*", aws_s3_bucket.kb_data.arn, "${aws_s3_bucket.kb_data.arn}/*"
      ]}
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sm_extra" {
  role       = aws_iam_role.sagemaker_exec.name
  policy_arn = aws_iam_policy.sm_bedrock_s3.arn
}

resource "aws_sagemaker_notebook_instance" "soc" {
  name                  = "${local.name}-nb"
  role_arn              = aws_iam_role.sagemaker_exec.arn
  instance_type         = var.sagemaker_instance_type
  direct_internet_access= "Enabled"
  tags                  = local.tags
}

# -----------------------------
# Outputs
# -----------------------------
output "guardduty_logs_bucket" { value = aws_s3_bucket.logs.bucket }
output "kb_data_bucket"       { value = aws_s3_bucket.kb_data.bucket }
output "lambda_name"          { value = aws_lambda_function.gd_processor.function_name }
output "sagemaker_notebook"   { value = aws_sagemaker_notebook_instance.soc.name }
