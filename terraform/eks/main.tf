resource "aws_kinesis_stream" "apm_test_stream" {
  #checkov:skip=CKV_AWS_43:demo only, not encryption is needed
  #checkov:skip=CKV_AWS_185:demo only, not encryption is needed
  name             = "apm_test2-gitlab"
  shard_count      = 2
}

resource "aws_sqs_queue" "apm_test_queue_" {
  #checkov:skip=CKV_AWS_27:demo only, not encryption is needed
  name                      = "apm_test2_-gitlab"
  delay_seconds             = 100
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 19
}

resource "aws_dynamodb_table" "test_2_table" {
  #checkov:skip=CKV2_AWS_16:demo only, autoscaling is not needed
  #checkov:skip=CKV_AWS_119:demo only, no encryption is needed

  name           = "test3newtable-gitlab"
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

}


module "iam_role_inline_policy" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role"

  name = "test-role-module-inline-policy-gitlab"

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
