# Terraform Deployment - GitHub Actions

This project deploys AWS infrastructure using Terraform through GitHub Actions CI/CD.

## Overview

- **CI/CD Platform**: GitHub Actions
- **Infrastructure as Code**: Terraform
- **Cloud Provider**: AWS
- **Authentication**: OIDC (OpenID Connect)
- **State Management**: AWS S3 Backend

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── terraform-deploy.yml    # GitHub Actions workflow
├── terraform/
│   └── eks/
│       ├── backend.tf              # S3 backend configuration
│       ├── main.tf                 # Main infrastructure resources
│       ├── provider.tf             # AWS provider configuration
│       └── versions.tf             # Provider version constraints
├── .gitlab-ci.yml                  # Legacy GitLab CI config (kept for reference)
└── GITLAB_MIGRATION_GUIDE.md       # Historical reference document
```

## Infrastructure Resources

All Terraform resources have the `-gitlab` suffix in their identifiers:

- **Kinesis Stream**: `aws_kinesis_stream.apm_test_stream-gitlab`
  - AWS Name: `apm_test2-gitlab`
  
- **SQS Queue**: `aws_sqs_queue.apm_test_queue_-gitlab`
  - AWS Name: `apm_test2_-gitlab`
  
- **DynamoDB Table**: `aws_dynamodb_table.test_2_table-gitlab`
  - AWS Name: `test3newtable-gitlab`
  
- **IAM Role Module**: `module.iam_role_inline_policy-gitlab`
  - AWS Name: `test-role-module-inline-policy-gitlab`

## GitHub Actions Workflow

### Triggers
- **Automatic**: Pushes to `main` branch
- **Manual**: Via workflow_dispatch

### Deployment Process
1. Checkout code
2. Configure AWS credentials via OIDC
3. Initialize Terraform with S3 backend
4. Generate deployment timestamp
5. Apply Terraform configuration

### Environment Variables
- `AWS_REGION`: us-west-2
- `TFSTATE_BUCKET`: betapdx-terraform-state
- `TFSTATE_KEY`: betapdx/terraform-deployment
- `TF_VAR_cluster_name`: petclinic-demo-gitlab
- `TF_VAR_cloudwatch_observability_addon_version`: v3.6.0-eksbuild.2

## AWS Configuration

### OIDC Authentication

The workflow uses GitHub OIDC to authenticate with AWS without storing credentials.

**Required AWS Resources**:
1. OIDC Identity Provider for GitHub
2. IAM Role: `github-oidc-role` (Account: 544546520146)

### IAM Trust Policy

The `github-oidc-role` must have a trust policy that allows GitHub Actions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::544546520146:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:BetaBuddyPDX/terraform-deployment:*"
        }
      }
    }
  ]
}
```

### Required IAM Permissions

The role needs permissions for:
- Kinesis stream operations
- SQS queue operations
- DynamoDB table operations
- IAM role creation and management
- S3 access to Terraform state bucket

## Setup Instructions

### 1. Configure GitHub Repository

Ensure the repository settings allow GitHub Actions to run.

### 2. Verify AWS OIDC Provider

Check that the GitHub OIDC provider exists in AWS IAM:
- Provider URL: `token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

If not present, create it in AWS IAM Console → Identity Providers.

### 3. Update IAM Trust Policy

Update the `github-oidc-role` trust policy with your repository path:
```
repo:YOUR_ORG/YOUR_REPO:*
```

### 4. Push to Main Branch

Push changes to the `main` branch to trigger the workflow:
```bash
git add .
git commit -m "Update infrastructure"
git push origin main
```

### 5. Monitor Workflow

Go to **Actions** tab in GitHub repository to monitor the workflow execution.

## Manual Deployment

To trigger a manual deployment:
1. Go to **Actions** tab in GitHub
2. Select **Terraform EKS Deployment** workflow
3. Click **Run workflow**
4. Select `main` branch
5. Click **Run workflow** button

## Deployment Timestamp

Each deployment includes a unique timestamp to force Terraform updates:
- Generated automatically during workflow execution
- Format: ISO 8601 (e.g., `2024-01-01T00:00:00Z`)
- Included in resource tags via `DeploymentTimestamp`

## State Management

Terraform state is stored remotely in AWS S3:
- **Bucket**: betapdx-terraform-state
- **Key**: betapdx/terraform-deployment
- **Region**: us-west-2

Backend configuration is passed during `terraform init` via command-line flags.

## Migration from GitLab

This project was previously using GitLab CI/CD. The migration involved:
1. Creating GitHub Actions workflow (`.github/workflows/terraform-deploy.yml`)
2. Updating Terraform resource identifiers with `-gitlab` suffix
3. Keeping GitLab configuration files for reference
4. Updating AWS IAM trust policy for GitHub OIDC

See `GITLAB_MIGRATION_GUIDE.md` for historical context.

## Troubleshooting

### Authentication Failures
- Verify OIDC provider exists in AWS
- Check IAM trust policy matches repository path
- Ensure role has correct permissions

### Terraform Errors
- Check S3 bucket exists and is accessible
- Verify backend configuration matches actual resources
- Review AWS resource quotas and limits

### Workflow Failures
- Check GitHub Actions logs for detailed error messages
- Verify environment variables are set correctly
- Ensure Terraform syntax is valid

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS OIDC for GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Terraform S3 Backend](https://www.terraform.io/language/settings/backends/s3)

## Tags

All resources are tagged with:
- `DeploymentTimestamp`: Unique deployment timestamp
- `ManagedBy`: Terraform
- `Environment`: demo
