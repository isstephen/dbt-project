#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-push}"

: "${AWS_REGION:?Set AWS_REGION}"
: "${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID}"
: "${ECR_REPOSITORY:?Set ECR_REPOSITORY}"
: "${IMAGE_TAG:?Set IMAGE_TAG}"

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

if [[ "${MODE}" != "build-only" ]]; then
  aws ecr describe-repositories \
    --region "${AWS_REGION}" \
    --repository-names "${ECR_REPOSITORY}" >/dev/null 2>&1 \
    || aws ecr create-repository \
      --region "${AWS_REGION}" \
      --repository-name "${ECR_REPOSITORY}" \
      --image-scanning-configuration scanOnPush=true \
      --encryption-configuration encryptionType=AES256 >/dev/null

  aws ecr get-login-password --region "${AWS_REGION}" \
    | docker login --username AWS --password-stdin "${ECR_REGISTRY}"
fi

docker build \
  --label org.opencontainers.image.source="dbt-openshift-ecr-demo" \
  --label org.opencontainers.image.description="dbt demo runtime for OpenShift" \
  -t "${IMAGE_URI}" \
  .

if [[ "${MODE}" != "build-only" ]]; then
  docker push "${IMAGE_URI}"
fi

printf '%s\n' "${IMAGE_URI}"
