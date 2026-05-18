# Architecture Blueprint: dbt + Redshift + ECR + GitHub Actions

## Current Goal

Build an enterprise-style data transformation demo where dbt code is packaged into a Docker image, pushed to Amazon ECR, and later executed on a runtime platform to transform data in Amazon Redshift.

The current runtime manifests are still OpenShift-based, but the core data platform target is now Redshift. ECS Fargate can replace OpenShift later if we want a fully AWS-native architecture.

## Current Repository

- GitHub repo: `isstephen/dbt-project`
- Local path: `/Users/yangyang/repos/dbt-project`
- Main branch: `main`
- Current successful Redshift commit: `3008224`
- ECR repository: `dbt-demo`
- AWS account: `732583169994`
- AWS region: `us-east-1`

## High-Level Architecture

```text
Developer laptop
  -> git push to GitHub

GitHub repository
  -> GitHub Actions workflow runs on push to main
  -> GitHub runner uses OIDC to assume AWS IAM role
  -> GitHub runner builds dbt Docker image
  -> GitHub runner pushes image to Amazon ECR

Amazon ECR
  -> stores immutable dbt image tagged by Git commit SHA

Runtime platform
  -> OpenShift CronJob today, ECS Fargate possible later
  -> pulls dbt image from ECR
  -> injects Redshift credentials from Secret
  -> runs dbt build

Amazon Redshift
  -> dbt seed creates demo raw_orders table
  -> dbt staging model cleans and casts raw data
  -> dbt mart model creates daily revenue metrics
```

## What Has Been Built

### dbt Project

Location: `dbt/`

The dbt project currently uses `dbt-redshift`.

Key files:

- `dbt/dbt_project.yml`
- `dbt/profiles.yml`
- `dbt/seeds/raw_orders.csv`
- `dbt/seeds/schema.yml`
- `dbt/models/staging/stg_orders.sql`
- `dbt/models/staging/schema.yml`
- `dbt/models/marts/fct_daily_orders.sql`
- `dbt/models/marts/schema.yml`

Transformation flow:

```text
raw_orders.csv
  -> raw_orders seed table in Redshift
  -> stg_orders view
  -> fct_daily_orders table
```

`stg_orders` performs data cleaning:

- casts order and customer IDs to strings
- casts order total to numeric
- normalizes order status to lowercase
- casts created_at to timestamp

`fct_daily_orders` performs transformation:

- groups orders by date
- counts orders
- calculates gross revenue
- calculates refunded revenue

### Docker Image

Location: `Dockerfile`

The Docker image:

- starts from `python:3.12-slim-bookworm`
- installs `dbt-core` and `dbt-redshift`
- copies the dbt project into `/app/dbt`
- runs `dbt deps` during image build
- runs as non-root user
- uses `scripts/run-dbt.sh` as the entrypoint

Runtime command:

```bash
dbt build --project-dir "${DBT_PROJECT_DIR}" --profiles-dir "${DBT_PROFILES_DIR}" --target "${DBT_TARGET:-prod}"
```

### GitHub Actions

Workflow: `.github/workflows/build-push-ecr.yml`

Trigger:

- automatically on push to `main` or `master`
- manually through `workflow_dispatch`

Main job:

```text
Build and push
  -> checkout code
  -> resolve image tag
  -> assume AWS IAM role through GitHub OIDC
  -> login to Amazon ECR
  -> ensure ECR repo exists
  -> docker build
  -> docker push
```

Current image tag strategy:

```text
ECR image tag = Git commit SHA
```

Latest verified image:

```text
732583169994.dkr.ecr.us-east-1.amazonaws.com/dbt-demo:3008224d4fec98f350c490e0927f200ace148119
```

### AWS IAM / OIDC

Template: `infra/aws/github-oidc-ecr-role.yml`

Bootstrap script: `scripts/create-github-aws-role.sh`

This was already run locally with AWS CLI. It created:

```text
CloudFormation stack: github-actions-dbt-ecr
IAM role: arn:aws:iam::732583169994:role/github-actions-dbt-ecr
```

Purpose:

- GitHub Actions does not store long-lived AWS access keys.
- GitHub Actions requests an OIDC token.
- AWS validates the token and allows only `isstephen/dbt-project` to assume the role.
- The runner receives temporary AWS credentials.
- The runner uses those credentials to push to ECR.

### GitHub Secrets and Variables

Repository Secret:

```text
AWS_ROLE_TO_ASSUME=arn:aws:iam::732583169994:role/github-actions-dbt-ecr
```

Repository Variables:

```text
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=732583169994
ECR_REPOSITORY=dbt-demo
OPENSHIFT_NAMESPACE=analytics-dbt
```

Optional variables/secrets for OpenShift deployment:

```text
OPENSHIFT_SERVER_URL
OPENSHIFT_TOKEN
OPENSHIFT_INSECURE_SKIP_TLS_VERIFY
```

## Current Verification Status

Already verified:

- GitHub repo exists.
- Local repo is pushed to `main`.
- GitHub Actions succeeds for commit `3008224`.
- ECR image exists in AWS.
- YAML files parse successfully.
- Shell scripts pass `bash -n`.

Verified ECR image:

```text
Repository: dbt-demo
Tag: 3008224d4fec98f350c490e0927f200ace148119
PushedAt: 2026-05-11 23:46:22 +12:00
Size: 137191511 bytes
```

Not yet verified end-to-end:

- Actual `dbt build` against a real Redshift cluster.
- OpenShift CronJob pulling the image and reaching Redshift.
- ECS Fargate runtime, if we choose to migrate away from OpenShift.

## OpenShift Runtime Design

Current manifests live in:

```text
deploy/openshift/base/
```

Main resources:

- `serviceaccount.yml`
- `cronjob.yml`
- `networkpolicy.yml`
- `secret-template.yml`
- `kustomization.yml`

The CronJob:

- pulls the dbt image from ECR
- reads Redshift connection settings from `dbt-demo-redshift`
- runs `scripts/run-dbt.sh`
- writes temporary dbt target/log files to `/tmp`
- runs with non-root and restricted container security settings

Redshift Secret name:

```text
dbt-demo-redshift
```

Expected secret keys:

```text
DBT_TARGET
REDSHIFT_HOST
REDSHIFT_PORT
REDSHIFT_DATABASE
REDSHIFT_SCHEMA
REDSHIFT_USER
REDSHIFT_PASSWORD
REDSHIFT_SSLMODE
DB_THREADS
```

## Local Scripts

### `scripts/create-github-aws-role.sh`

One-time bootstrap script.

Creates the GitHub OIDC IAM role through CloudFormation.

### `scripts/build-and-push.sh`

Local equivalent of the GitHub Actions build/push logic.

Requires local Docker and AWS CLI.

### `scripts/create-db-secret.sh`

Creates the OpenShift Secret containing Redshift connection settings.

Despite the filename, it now creates:

```text
dbt-demo-redshift
```

### `scripts/create-ecr-pull-secret.sh`

Creates an OpenShift Docker registry secret for pulling images from ECR.

### `scripts/deploy-openshift.sh`

Applies OpenShift manifests and updates the CronJob image.

### `scripts/run-dbt.sh`

Container entrypoint.

Runs:

```bash
dbt build
```

## How To Continue Later

### Check GitHub Actions

```bash
gh run list --repo isstephen/dbt-project
gh run view --repo isstephen/dbt-project
```

### Check ECR Image

```bash
aws ecr describe-images \
  --region us-east-1 \
  --repository-name dbt-demo \
  --query 'imageDetails[*].{tags:imageTags,pushed:imagePushedAt,size:imageSizeInBytes}' \
  --output table
```

### Trigger GitHub Actions Manually

```bash
gh workflow run "Build dbt image and push to ECR" \
  --repo isstephen/dbt-project
```

### Create Redshift Secret in OpenShift

Create `.env` from `.env.example`, fill real Redshift values, then run:

```bash
source .env
./scripts/create-db-secret.sh
```

### Deploy to OpenShift

```bash
source .env
./scripts/create-ecr-pull-secret.sh
./scripts/deploy-openshift.sh
```

### Trigger OpenShift Job Manually

```bash
oc -n "${OPENSHIFT_NAMESPACE}" create job \
  --from=cronjob/dbt-demo \
  dbt-demo-manual-$(date +%Y%m%d%H%M%S)
```

### View OpenShift Logs

```bash
oc -n "${OPENSHIFT_NAMESPACE}" logs \
  -l app.kubernetes.io/name=dbt-demo \
  --tail=200
```

## Possible Next Architecture: ECS Instead Of OpenShift

ECS is a good replacement if the goal is a fully AWS-native demo.

Target AWS-native architecture:

```text
GitHub Actions
  -> build dbt image
  -> push to ECR

EventBridge Scheduler
  -> triggers ECS Fargate task

ECS Fargate
  -> pulls dbt image from ECR
  -> reads Redshift credentials from AWS Secrets Manager
  -> runs dbt build
  -> writes logs to CloudWatch Logs

Redshift
  -> stores transformed tables
```

New AWS resources needed for ECS:

- ECS cluster
- ECS task definition
- ECS task execution role
- ECS task role
- CloudWatch log group
- Secrets Manager secret for Redshift credentials
- EventBridge schedule
- Security group/subnet configuration that can reach Redshift

If moving to ECS, OpenShift files can be kept as reference or replaced by:

```text
deploy/ecs/
scripts/deploy-ecs-task.sh
scripts/run-ecs-task.sh
scripts/create-redshift-secret.sh
```

## Interview Explanation

Short version:

> This project demonstrates an enterprise-style dbt transformation pipeline on AWS. Code is stored in GitHub. When code is pushed to main, GitHub Actions runs a CI workflow. The workflow uses GitHub OIDC to assume an AWS IAM role, avoiding long-lived AWS keys. It builds a Docker image containing the dbt project and pushes that image to Amazon ECR. The runtime platform then pulls the image, injects Redshift credentials from a secret store, and runs `dbt build` to create staging and mart models in Redshift.

Key security points:

- No AWS access keys are stored in GitHub.
- GitHub Actions uses short-lived credentials through OIDC.
- Redshift credentials are not stored in code.
- Runtime credentials are injected through platform secrets.
- Image tags use commit SHA for traceability.

Key data engineering points:

- dbt owns transformation logic, not ingestion.
- Redshift is the warehouse where transformations run.
- staging models clean and standardize data.
- mart models create business-ready tables.
- dbt tests validate data assumptions.
