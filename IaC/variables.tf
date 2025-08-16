variable "project" {
  description = "Project name prefix for resources"
  type        = string
  default     = "multicloud-soc"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "sagemaker_instance_type" {
  description = "SageMaker notebook instance type"
  type        = string
  default     = "ml.t3.medium"
}

variable "bedrock_model_id" {
  description = "Bedrock model ID to invoke from Lambda (region-specific). Example: anthropic.claude-3-5-sonnet-20240620-v1:0"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20240620-v1:0"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {
    app     = "multicloud-threat-detection"
    managed = "terraform"
  }
}
