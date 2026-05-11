#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}"
: "${GITHUB_OWNER:?Set GITHUB_OWNER}"
: "${GITHUB_REPO:?Set GITHUB_REPO}"
: "${ECR_REPOSITORY:?Set ECR_REPOSITORY}"

STACK_NAME="${STACK_NAME:-github-actions-dbt-ecr}"
ROLE_NAME="${ROLE_NAME:-github-actions-dbt-ecr}"

aws cloudformation deploy \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --template-file infra/aws/github-oidc-ecr-role.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    GitHubOwner="${GITHUB_OWNER}" \
    GitHubRepo="${GITHUB_REPO}" \
    EcrRepositoryName="${ECR_REPOSITORY}" \
    RoleName="${ROLE_NAME}"

aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='RoleArn'].OutputValue" \
  --output text
