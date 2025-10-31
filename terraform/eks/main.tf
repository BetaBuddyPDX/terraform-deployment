locals {
  deployment_timestamp = var.deployment_timestamp
  
  common_tags = {
    DeploymentTimestamp = local.deployment_timestamp
    ManagedBy          = "Terraform"
    Environment        = "demo"
  }
}

variable "deployment_timestamp" {
  description = "Timestamp of deployment to force Terraform updates"
  type        = string
  default     = "2024-01-01T00:00:00Z"
}

resource "aws_kinesis_stream" "apm_test_stream-gitlab" {
  #checkov:skip=CKV_AWS_43:demo only, not encryption is needed
  #checkov:skip=CKV_AWS_185:demo only, not encryption is needed
  name             = "apm_test2-github-gitlab"
  shard_count      = 2
  
  tags = local.common_tags
}

resource "aws_sqs_queue" "apm_test_queue_-gitlab" {
  #checkov:skip=CKV_AWS_27:demo only, not encryption is needed
  name                      = "apm_test2_github-gitlab"
  delay_seconds             = 100
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 19
  
  tags = local.common_tags
}

resource "aws_dynamodb_table" "test_2_table-gitlab" {
  #checkov:skip=CKV2_AWS_16:demo only, autoscaling is not needed
  #checkov:skip=CKV_AWS_119:demo only, no encryption is needed

  name           = "test3newtable-github-gitlab"
  billing_mode   = "PROVISIONED"
  read_capacity  = 2
  write_capacity = 5
  hash_key       = "id"

  point_in_time_recovery {
   enabled = true
  }

  # server_side_encryption {
  #   enabled     = true
  # }

  attribute {
    name = "id"
    type = "S"
  }
  
  tags = local.common_tags
}


module "iam_role_inline_policy-gitlab" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role"

  name = "test-role-github-gitlab"

  create_instance_profile = true

  trust_policy_permissions = {
    ec2 = {
      effect = "Allow"
      actions = [
        "sts:AssumeRole"
      ]
      principals = [{
        type        = "Service"
        identifiers = ["ec2.amazonaws.com"]
      }]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    S3ReadAccess = {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      resources = [
        "arn:aws:s3:::example-bucket",
        "arn:aws:s3:::example-bucket/*"
      ]
    }
  }
}
