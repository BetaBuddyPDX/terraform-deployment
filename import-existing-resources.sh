#!/bin/bash
# Script to import existing GitHub resources into new Terraform state

set -e

echo "Importing existing AWS resources into Terraform state..."

cd terraform/eks

# Initialize with the GitHub state file
terraform init \
  -backend-config="bucket=betapdx-terraform-state" \
  -backend-config="key=betapdx/terraform-deployment-github" \
  -backend-config="region=us-west-2"

# Import DynamoDB Table
echo "Importing DynamoDB table..."
terraform import 'aws_dynamodb_table.test_2_table-github' 'test3newtable-github'

# Import Kinesis Stream
echo "Importing Kinesis stream..."
terraform import 'aws_kinesis_stream.apm_test_stream-github' 'apm_test2-github'

# Import SQS Queue
echo "Importing SQS queue..."
terraform import 'aws_sqs_queue.apm_test_queue_-github' 'https://sqs.us-west-2.amazonaws.com/544546520146/apm_test2_-github'

# Import IAM Role (find the actual role name first)
ROLE_NAME=$(aws iam list-roles --query 'Roles[?starts_with(RoleName, `test-role-github-`)].RoleName' --output text | head -n1)
if [ ! -z "$ROLE_NAME" ]; then
  echo "Importing IAM role: $ROLE_NAME"
  terraform import 'module.iam_role_inline_policy-github.aws_iam_role.this[0]' "$ROLE_NAME"
  
  # Import IAM Role Policy
  POLICY_NAME=$(aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames[0]' --output text)
  if [ ! -z "$POLICY_NAME" ]; then
    echo "Importing IAM role policy: $POLICY_NAME"
    terraform import "module.iam_role_inline_policy-github.aws_iam_role_policy.inline[0]" "${ROLE_NAME}:${POLICY_NAME}"
  fi
  
  # Import Instance Profile
  PROFILE_NAME=$(aws iam list-instance-profiles-for-role --role-name "$ROLE_NAME" --query 'InstanceProfiles[0].InstanceProfileName' --output text)
  if [ ! -z "$PROFILE_NAME" ]; then
    echo "Importing instance profile: $PROFILE_NAME"
    terraform import "module.iam_role_inline_policy-github.aws_iam_instance_profile.this[0]" "$PROFILE_NAME"
  fi
fi

echo "Import complete! Run 'terraform plan' to verify."
