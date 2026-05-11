#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}"
: "${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID}"
: "${OPENSHIFT_NAMESPACE:?Set OPENSHIFT_NAMESPACE}"

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_PASSWORD="$(aws ecr get-login-password --region "${AWS_REGION}")"

oc -n "${OPENSHIFT_NAMESPACE}" create secret docker-registry dbt-demo-ecr-pull \
  --docker-server="${ECR_REGISTRY}" \
  --docker-username=AWS \
  --docker-password="${ECR_PASSWORD}" \
  --dry-run=client -o yaml \
  | oc apply -f -
