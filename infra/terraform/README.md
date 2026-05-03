# Terraform Setup

This folder now covers both project infrastructure phases for ShopSmart.

## Phase 2 coverage

- One Amazon S3 bucket with a unique generated name
- Bucket versioning enabled
- Server-side encryption enabled
- Public access fully blocked

## Phase 3 coverage

- One ECR repository for the root application image
- Dedicated VPC with two public subnets for ECS and two private subnets for RDS
- Application Load Balancer for the single app container
- One RDS MySQL instance in private subnets
- ECS cluster and Fargate service
- Single ECS task definition containing only the app container
- CloudWatch logging and required ECS IAM roles

## Files

- `main.tf`: Terraform and provider setup plus the Phase 2 S3 resources
- `phase3.tf`: Networking, ECR, ALB, RDS, ECS, and IAM resources for manual Phase 3 deployment
- `variables.tf`: Input variables
- `outputs.tf`: Useful output values after apply
- `terraform.tfvars.example`: Example variable values

## Manual deployment order

Keep the project workflow in this order:

1. Push or open a PR
2. Run tests
3. Terraform apply for infrastructure
4. Docker build and push to ECR
5. Terraform apply again for ECS deployment

## GitHub Actions automation

The repository workflow extends CI into deployment with this sequence on pushes to the default branch:

1. Run tests
2. Apply foundation Terraform resources
3. Build and push the Docker image to ECR
4. Apply Terraform again with `enable_ecs_deployment = true` and a commit-specific image tag

PRs stop at tests and Terraform validation.

### One-time remote state setup

The workflow expects Terraform state to live in S3. Because your resources already exist from local applies, migrate local state once before using GitHub Actions:

```bash
terraform init -migrate-state \
  -backend-config="bucket=<tf-state-bucket>" \
  -backend-config="key=<tf-state-key>" \
  -backend-config="region=<aws-region>" \
  -backend-config="encrypt=true"
```

After migration, GitHub Actions and your local machine should both use the same backend config when applying changes.

## How to use

1. Copy the example file:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Update `terraform.tfvars` with your own bucket prefix and any image tags you want to deploy.
   In restricted lab accounts, set `create_ecs_iam_roles = false` and point `ecs_execution_role_arn` plus `ecs_task_role_arn` at an existing role such as `LabRole`.

3. Authenticate to AWS using either:

   ```bash
   aws configure
   ```

   or export credentials in your shell:

   ```bash
   export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY_ID"
   export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_ACCESS_KEY"
   export AWS_DEFAULT_REGION="ap-south-1"
   ```

4. Initialize and validate:

   ```bash
   terraform init
   terraform fmt
   terraform validate
   ```

5. Provision the base infrastructure first:

   Make sure `enable_ecs_deployment = false` in `terraform.tfvars`, then run:

   ```bash
   terraform plan
   terraform apply
   ```

   This creates the S3 bucket, ECR repository, VPC, public and private subnets, ALB, ECS cluster, RDS instance, and related networking, but it does not create the ECS service yet. IAM roles are created only when `create_ecs_iam_roles = true`.

6. Build and push the root application image to ECR:

   ```bash
   APP_REPO=$(terraform output -raw app_ecr_repository_url)

   aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin "$(echo "$APP_REPO" | cut -d/ -f1)"

   docker buildx build --platform linux/arm64 -t "$APP_REPO:latest" --push .
   ```

   Build for `linux/arm64` when `ecs_cpu_architecture = "ARM64"`. If you switch Terraform to `X86_64`, build for `linux/amd64` instead.

7. Enable the ECS deployment and apply again:

   Update `terraform.tfvars`:

   ```hcl
   enable_ecs_deployment = true
   app_image_tag         = "latest"
   ```

   Then run:

   ```bash
   terraform plan
   terraform apply
   ```

## Verification commands

Confirm the images reached ECR:

```bash
aws ecr describe-images --repository-name shopsmart-dev-app
```

Confirm ECS is running:

```bash
aws ecs describe-services --cluster shopsmart-dev-cluster --services shopsmart-dev-service
aws ecs list-tasks --cluster shopsmart-dev-cluster --service-name shopsmart-dev-service
```

Confirm the application responds through the ALB:

```bash
curl http://<alb-dns-name>/
curl http://<alb-dns-name>/api/health
```

Confirm RDS exists and is available:

```bash
aws rds describe-db-instances --db-instance-identifier shopsmart-dev-mysql
```

## Notes

- Manual deployment is still supported, and GitHub Actions can now automate the same Terraform plus ECR plus ECS flow after state is migrated to S3.
- Local Docker Compose uses MySQL, while AWS uses RDS MySQL.
- `docker-compose.yml` is needed for local development.
- `docker-entrypoint.sh` is needed in both local and AWS runs because it applies Prisma migrations before starting the app.
