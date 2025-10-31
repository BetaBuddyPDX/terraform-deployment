# GitLab CI/CD Migration Guide - pet-clinic-infra

> **⚠️ NOTE: This project has been migrated back to GitHub Actions**
> 
> This document is kept for historical reference only. The project now uses:
> - **CI/CD Platform**: GitHub Actions
> - **Workflow File**: `.github/workflows/terraform-deploy.yml`
> - **Resource Naming**: All Terraform resource identifiers have `-gitlab` suffix
> - **Active Documentation**: See `README.md` for current setup
>
> The information below describes the original GitLab migration and is preserved for reference.

---

## Migration Summary

**Original Workflow**: `.github/workflows/terraform-deploy.yml`  
**New Configuration**: `.gitlab-ci.yml`  
**AWS Account**: 544546520146  
**Primary Change**: OIDC authentication migration from GitHub to GitLab

---

## Key Technical Changes

### 1. OIDC Authentication Method

**GitHub Actions (Old)**:
```yaml
permissions:
  id-token: write
  contents: read

- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    role-to-assume: arn:aws:iam::544546520146:role/githubrole
    aws-region: us-west-2
```

**GitLab CI/CD (New)**:
```yaml
id_tokens:
  GITLAB_OIDC_TOKEN:
    aud: https://gitlab.com

before_script:
  - |
    export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
    $(aws sts assume-role-with-web-identity \
    --role-arn ${AWS_ROLE_ARN} \
    --role-session-name "gitlab-${CI_PROJECT_NAME}-${CI_PIPELINE_ID}" \
    --web-identity-token ${GITLAB_OIDC_TOKEN} \
    --duration-seconds 3600 \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text))
```

**Note**: The `|` (pipe) character enables YAML literal block scalar for multi-line commands with proper backslash line continuation.

**Critical Points**:
- GitLab deprecated `CI_JOB_JWT_V2` - must use ID tokens instead
- ID token accessed via `$GITLAB_OIDC_TOKEN` environment variable
- Must specify `aud: https://gitlab.com` in token configuration
- AWS STS assume-role-with-web-identity command required for authentication

### 2. Pipeline Configuration Structure

| Aspect | GitHub Actions | GitLab CI/CD |
|--------|---------------|--------------|
| **Config File** | `.github/workflows/terraform-deploy.yml` | `.gitlab-ci.yml` (root) |
| **Trigger Syntax** | `on: push: branches:` | `workflow: rules:` |
| **Manual Trigger** | `workflow_dispatch` | `if: $CI_PIPELINE_SOURCE == "web"` |
| **Concurrency** | `concurrency: group:` | `resource_group:` |
| **Working Directory** | `working-directory:` | `cd` commands in script |

### 3. Environment Variables

**GitHub Actions** → **GitLab CI/CD**:
- `${{ env.VAR }}` → `$VAR` or `${VAR}`
- `${{ github.workflow }}` → `$CI_PROJECT_NAME`
- Custom env vars use same syntax in both

### 4. Terraform Image and Entrypoint Override

Using `hashicorp/terraform:latest` image which is Alpine-based:

**Critical**: The Terraform image has `terraform` as its default entrypoint, which means all commands are interpreted as terraform commands. Must override with empty entrypoint:

```yaml
terraform-deploy:
  image:
    name: hashicorp/terraform:latest
    entrypoint: [""]  # Required to run shell commands
  before_script:
    - apk add --no-cache python3 py3-pip curl aws-cli
```

**Important Notes**:
- The `entrypoint` must be nested under `image:` configuration. Without this override, commands like `apk add` will fail with "Terraform has no command named 'sh'".
- AWS CLI is installed directly from Alpine's package manager (`apk add aws-cli`) to avoid Python's externally-managed-environment restrictions in newer Alpine versions.

---

## AWS IAM Configuration

### Required IAM Trust Policy Update

The existing `gitlab-oidc-role` IAM role needs its trust policy updated to include this project path.

**Update Trust Policy** in AWS IAM Console:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::544546520146:oidc-provider/gitlab.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "gitlab.com:aud": "https://gitlab.com"
        },
        "StringLike": {
          "gitlab.com:sub": [
            "project_path:carlosluo223-group/hanfangl-test-repo:ref_type:branch:ref:main",
            "project_path:YOUR_GITLAB_GROUP/pet-clinic-infra:ref_type:branch:ref:main"
          ]
        }
      }
    }
  ]
}
```

**Replace** `YOUR_GITLAB_GROUP/pet-clinic-infra` with your actual GitLab project path.

### Verify OIDC Provider Exists

The OIDC provider should already exist from the previous migration:
- **Provider URL**: `https://gitlab.com`
- **Audience**: `https://gitlab.com`

If not present, create it:
1. Go to AWS IAM Console → Identity Providers → Add Provider
2. Choose **OpenID Connect**
3. Provider URL: `https://gitlab.com`
4. Audience: `https://gitlab.com`
5. Click **Get Thumbprint** → **Add Provider**

### IAM Role Permissions

Ensure the `gitlab-oidc-role` has sufficient permissions for Terraform operations:
- EKS cluster creation/management
- VPC and networking resources
- IAM roles and policies for EKS
- CloudWatch resources
- S3 access to Terraform state bucket

**Minimum Required Policies**:
- `AmazonEKSClusterPolicy`
- `AmazonEKSServicePolicy`
- Custom policy for S3 state bucket access
- Custom policy for VPC/networking operations
- Custom policy for IAM role management

---

## GitLab Project Setup

### 1. Create GitLab Repository

If not already created:
```bash
# Navigate to project directory
cd /Volumes/workplace/pet-clinic-infra

# Add GitLab remote (if needed)
git remote add gitlab https://gitlab.com/YOUR_GROUP/pet-clinic-infra.git

# Or set as origin
git remote set-url origin https://gitlab.com/YOUR_GROUP/pet-clinic-infra.git
```

### 2. Push Code to GitLab

```bash
# Push main branch
git push -u gitlab main

# Or if gitlab is origin
git push -u origin main
```

### 3. Verify Pipeline Configuration

Once pushed, go to your GitLab project:
1. Navigate to **CI/CD → Pipelines**
2. Check if pipeline is running or click **Run Pipeline**
3. Monitor job execution in real-time

---

## Pipeline Behavior

### Automatic Triggers
- Pushes to `main` branch automatically trigger the pipeline
- Uses `resource_group: terraform-deployment` to prevent concurrent runs

### Manual Triggers
- Can be triggered manually from GitLab UI:
  - **CI/CD → Pipelines → Run Pipeline**
  - Select branch → **Run Pipeline**

### Job Flow
1. **terraform-deploy**:
   - Installs AWS CLI on Alpine-based Terraform image
   - Authenticates to AWS using OIDC ID token
   - Initializes Terraform with remote S3 backend
   - Applies Terraform configuration with `--auto-approve`

---

## Testing the Migration

### 1. Verify AWS Authentication

Check the pipeline logs for:
```
# Should see successful authentication
aws sts get-caller-identity
```

Expected output includes:
- Account: 544546520146
- UserId: Contains role session name
- Arn: Contains `gitlab-oidc-role`

### 2. Verify Terraform Operations

Pipeline should successfully:
- Initialize backend with S3 state bucket
- Download required providers
- Plan infrastructure changes
- Apply changes to AWS

### 3. Common Issues and Solutions

**Issue**: `AccessDenied` when assuming role  
**Solution**: Verify trust policy includes correct GitLab project path

**Issue**: Terraform backend initialization fails  
**Solution**: Check S3 bucket exists and IAM role has access

**Issue**: Token expired during long operations  
**Solution**: Duration set to 3600 seconds (1 hour) - increase if needed

---

## Variables Reference

All variables are defined in `.gitlab-ci.yml`:

| Variable | Value | Purpose |
|----------|-------|---------|
| `AWS_REGION` | us-west-2 | AWS region for resources |
| `TFSTATE_KEY` | application-signals/demo-applications | S3 state file key |
| `TFSTATE_BUCKET` | tfstate-csdelivery-test-bucket | S3 bucket for state |
| `TFSTATE_REGION` | us-west-2 | Region for state bucket |
| `TF_VAR_cluster_name` | petclinic-demo | EKS cluster name |
| `TF_VAR_cloudwatch_observability_addon_version` | v3.6.0-eksbuild.2 | CloudWatch addon version |
| `AWS_ROLE_ARN` | arn:aws:iam::544546520146:role/gitlab-oidc-role | IAM role to assume |

---

## Differences from Previous Migration (hanfangl-test-repo)

| Aspect | hanfangl-test-repo | pet-clinic-infra |
|--------|-------------------|------------------|
| **Technology** | Java/Maven + CloudFormation | Terraform + EKS |
| **Pipeline Stages** | 4 (build, deploy, test, report) | 1 (deploy) |
| **Build Process** | Maven build → Docker image | N/A (Infrastructure only) |
| **Deployment** | CloudFormation stack | Terraform apply |
| **Image Issues** | `amazon/aws-cli` needs `entrypoint: [""]` | `hashicorp/terraform` needs `entrypoint: [""]` |
| **Complexity** | Multi-stage with artifacts | Single-stage deployment |

**Common Pattern**: Both projects require `entrypoint: [""]` override because their Docker images have non-shell entrypoints that prevent running shell commands in `before_script` and `script` sections.

---

## Rollback Plan

If issues occur after migration:

### Quick Rollback to GitHub Actions
1. Re-enable GitHub Actions workflow
2. Update GitHub repository settings to allow Actions
3. Push to GitHub to trigger workflow

### Gradual Migration
- Keep both pipelines active initially
- Monitor GitLab pipeline for several runs
- Disable GitHub Actions once confident

---

## Next Steps

1. ✅ Configuration files created
2. ⏳ Update AWS IAM trust policy with correct GitLab project path
3. ⏳ Push `.gitlab-ci.yml` to GitLab repository
4. ⏳ Test pipeline execution
5. ⏳ Verify EKS cluster deployment
6. ⏳ Monitor for any issues
7. ⏳ Disable GitHub Actions workflow (optional)

---

## Resources

- [GitLab CI/CD YAML Reference](https://docs.gitlab.com/ee/ci/yaml/)
- [GitLab OIDC Token Documentation](https://docs.gitlab.com/ee/ci/secrets/id_token_authentication.html)
- [AWS STS AssumeRoleWithWebIdentity](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html)
- [Terraform Backend Configuration](https://www.terraform.io/language/settings/backends/s3)
- [HashiCorp Terraform Docker Image](https://hub.docker.com/r/hashicorp/terraform)

---

## Support

For issues with:
- **GitLab CI/CD**: Check pipeline logs and GitLab documentation
- **AWS Authentication**: Verify IAM trust policy and OIDC provider configuration
- **Terraform**: Check Terraform state and backend configuration
- **EKS Deployment**: Review Terraform plan output and AWS console

---

*Migration completed: January 2025*  
*AWS Account: 544546520146*  
*GitLab OIDC Role: gitlab-oidc-role*
