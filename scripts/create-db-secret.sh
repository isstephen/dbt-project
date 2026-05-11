#!/usr/bin/env bash
set -euo pipefail

: "${OPENSHIFT_NAMESPACE:?Set OPENSHIFT_NAMESPACE}"
: "${DBT_TARGET:?Set DBT_TARGET}"
: "${DB_HOST:?Set DB_HOST}"
: "${DB_PORT:?Set DB_PORT}"
: "${DB_NAME:?Set DB_NAME}"
: "${DB_SCHEMA:?Set DB_SCHEMA}"
: "${DB_USER:?Set DB_USER}"
: "${DB_PASSWORD:?Set DB_PASSWORD}"
: "${DB_THREADS:?Set DB_THREADS}"

oc -n "${OPENSHIFT_NAMESPACE}" create secret generic dbt-demo-db \
  --from-literal=DBT_TARGET="${DBT_TARGET}" \
  --from-literal=DB_HOST="${DB_HOST}" \
  --from-literal=DB_PORT="${DB_PORT}" \
  --from-literal=DB_NAME="${DB_NAME}" \
  --from-literal=DB_SCHEMA="${DB_SCHEMA}" \
  --from-literal=DB_USER="${DB_USER}" \
  --from-literal=DB_PASSWORD="${DB_PASSWORD}" \
  --from-literal=DB_THREADS="${DB_THREADS}" \
  --dry-run=client -o yaml \
  | oc apply -f -
