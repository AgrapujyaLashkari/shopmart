# ShopSmart

ShopSmart is a full-stack web application with React on the frontend and Express + Prisma on the backend.

## Architecture

- Frontend: React + Vite app in `client/`
- Backend: Express API in `server/`
- Database: Mysql through Prisma ORM
- Testing:
	- Frontend unit/integration: Vitest + React Testing Library + MSW
	- Frontend E2E: Playwright
	- Backend API tests: Jest + Supertest

### Runtime Flow

1. User interacts with frontend routes (`/`, `/login`, `/signup`, `/products/:id`).
2. Frontend calls backend APIs (`/api/auth/*`, `/api/products`, `/api/health`).
3. Backend handles auth/business logic and talks to Prisma where needed.
4. Responses are rendered in React UI.

## CI/CD Workflow

- CI file: `.github/workflows/ci.yml`
- Triggers:
	- `push`
	- `pull_request`
- Pipeline checks:
	- Install dependencies for client and server
	- Run ESLint
	- Run Prettier check
	- Run tests
- Deployment sequence on pushes to the default branch:
	- Terraform foundation apply
	- Docker build and push to ECR
	- Terraform deploy apply to update ECS

## Design Decisions

- Kept auth concerns in `AuthContext` for reusable state handling.
- Added API helper functions under `client/src/api/` to avoid duplicate fetch logic.
- Introduced `products` endpoints for clear frontend-backend integration.
- Used test IDs in core UI for stable UI and E2E test selectors.
- Added idempotent setup script behavior to support repeatable environment setup.

## Challenges and Trade-offs

- Ensuring new product pages did not break existing auth/health tests.
- Balancing strict CI checks with current project structure (separate client/server packages).
- Making setup script rerunnable without damaging existing local state.

## Required Project Notes

1. Mysql is used for local database storage.
2. Prisma is used as ORM.
3. API endpoints are implemented for auth and product retrieval.
4. Deploy configuration can target backend (Render) and frontend (Vercel).
5. CORS is enabled in backend middleware and can be tuned for deployed domains.

## Phase 2 Infrastructure

Terraform files for AWS infrastructure are in `infra/terraform/`.

Current Phase 2 coverage:

- Amazon S3 bucket with a unique generated name
- Versioning enabled
- Default server-side encryption enabled
- Public access blocked

See `infra/terraform/README.md` for setup and execution steps.

## Phase 3 Containerization and ECS

Phase 3 is now scaffolded in the repository with:

- One root-level multi-stage `Dockerfile` for the whole application
- Frontend built during image creation and served by the Express runtime
- Non-root runtime user and healthcheck in the application container
- Root `docker-compose.yml` for `app + MySQL`
- Terraform resources for ECR, VPC, ALB, RDS, ECS cluster, task definition, and Fargate service

### Local `.env` values

When you run:

```bash
cp .env.compose.example .env
```

the `.env` file is for Docker Compose in the repo root, not for `server/.env`.

Set these values in `.env`:

- `APP_PORT`: host port for the application, usually `5001`
- `MYSQL_DATABASE`: local MySQL database name
- `MYSQL_USER`: local MySQL application user
- `MYSQL_PASSWORD`: local MySQL application password
- `MYSQL_ROOT_PASSWORD`: local MySQL root password
- `JWT_SECRET`: JWT signing secret for local auth
- `JWT_EXPIRES_IN`: token expiry, for example `7d`
- `RUN_DB_MIGRATIONS`: usually `true`
- `DB_MIGRATION_MAX_ATTEMPTS`: retry count while waiting for MySQL, usually `20`

Do not add `DATABASE_URL` to this `.env`. `docker-compose.yml` builds it automatically from the `MYSQL_*` values and passes it to the app container.

### Local container workflow

1. Copy the example environment file:

   ```bash
   cp .env.compose.example .env
   ```

2. Start the full stack:

   ```bash
   docker compose up --build
   ```

3. Verify locally:

   ```bash
   curl http://localhost:5001/api/health
   curl http://localhost:5001
   ```

Open the full application at `http://localhost:5001`.

### Manual AWS deployment flow

The ECS deployment is intentionally manual and not wired into CI.

1. Run tests through the existing CI or locally.
2. Provision infrastructure first with Terraform while keeping `enable_ecs_deployment = false`.
3. This first apply creates the S3 bucket, VPC, subnets, security groups, ALB, ECS cluster, ECR repository, and RDS MySQL instance.
   In restricted lab accounts, configure Terraform to reuse existing IAM roles instead of trying to create new ones.
4. Build and push the single root application image to the ECR repository created by Terraform.
5. Set `enable_ecs_deployment = true` and re-run `terraform apply` to create the ECS task definition and service.
6. Verify the service through the ALB DNS name and ECS service status.

The ECS task definition now pins an explicit CPU architecture. Keep the ECR image architecture aligned with Terraform:

- `ecs_cpu_architecture = "ARM64"` -> build with `docker buildx build --platform linux/arm64`
- `ecs_cpu_architecture = "X86_64"` -> build with `docker buildx build --platform linux/amd64`

## GitHub Actions Setup

The workflow now supports this order on pushes to the repository default branch:

1. Push or PR triggers the workflow
2. Run tests
3. Terraform apply for foundation infrastructure
4. Docker build and push to ECR
5. Terraform apply for ECS deployment

PRs run tests and Terraform validation only. AWS deployment jobs are gated to pushes on the default branch so infrastructure is not applied from every PR.

### One-time state migration

Before the workflow can manage your existing AWS resources, move Terraform state from your local machine to S3.

From [infra/terraform](/Users/agrapujyalashkari/Desktop/DevOps%20Class/shopsmart/infra/terraform):

```bash
terraform init -migrate-state \
  -backend-config="bucket=<tf-state-bucket>" \
  -backend-config="key=<tf-state-key>" \
  -backend-config="region=<aws-region>" \
  -backend-config="encrypt=true"
```

For coursework, you can use the Phase 2 S3 bucket as the backend bucket if you already created it manually, though a separate backend bucket is cleaner.

### GitHub Secrets

Add these in GitHub: `Settings -> Secrets and variables -> Actions -> Secrets`

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

Use `AWS_SESSION_TOKEN` only if your AWS credentials are temporary. If you are using an AWS Academy or voclabs account, the workflow will stop working when those temporary credentials expire. For a durable deployment workflow, use long-lived IAM credentials or an OIDC-based role.

### GitHub Variables

Add these in GitHub: `Settings -> Secrets and variables -> Actions -> Variables`

- `AWS_REGION`
  Use `us-east-1` for your current setup.
- `TF_STATE_BUCKET`
  The S3 bucket that stores Terraform state.
- `TF_STATE_KEY`
  Example: `terraform/shopsmart-dev.tfstate`
- `TF_BUCKET_NAME_PREFIX`
  Example: `shopsmart-agrapujya-dev`
- `TF_ECS_EXECUTION_ROLE_ARN`
  Example: `arn:aws:iam::871800143796:role/LabRole`
- `TF_ECS_TASK_ROLE_ARN`
  Example: `arn:aws:iam::871800143796:role/LabRole`

Optional variables if you want to override defaults:

- `TF_PROJECT_NAME`
- `TF_ENVIRONMENT`
- `TF_CREATE_ECS_IAM_ROLES`
- `TF_MYSQL_DATABASE_NAME`
- `TF_MYSQL_USERNAME`
- `TF_DB_INSTANCE_CLASS`
- `TF_RDS_MULTI_AZ`
- `TF_ECS_CPU_ARCHITECTURE`

Defaults used by the workflow when optional variables are not set:

- project name: `shopsmart`
- environment: `dev`
- create ECS IAM roles: `false`
- MySQL database: `shopsmart`
- MySQL username: `shopsmart`
- DB instance class: `db.t3.micro`
- RDS multi AZ: `false`
- ECS CPU architecture: `ARM64`

### Terraform-generated secrets

These are not stored in GitHub secrets right now:

- RDS database password
- ECS app JWT secret

Terraform generates them with `random_password` and stores them in Terraform state. Because of that, protect the S3 backend bucket carefully.
