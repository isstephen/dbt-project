#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}"
: "${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID}"
: "${ECR_REPOSITORY:?Set ECR_REPOSITORY}"
: "${IMAGE_TAG:?Set IMAGE_TAG}"
: "${OPENSHIFT_NAMESPACE:?Set OPENSHIFT_NAMESPACE}"

IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"

oc new-project "${OPENSHIFT_NAMESPACE}" >/dev/null 2>&1 || true
oc -n "${OPENSHIFT_NAMESPACE}" apply -k deploy/openshift/base
oc -n "${OPENSHIFT_NAMESPACE}" set image cronjob/dbt-demo dbt="${IMAGE_URI}"
