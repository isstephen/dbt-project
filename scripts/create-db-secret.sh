#!/usr/bin/env bash
set -euo pipefail

: "${OPENSHIFT_NAMESPACE:?Set OPENSHIFT_NAMESPACE}"
: "${DBT_TARGET:?Set DBT_TARGET}"
: "${REDSHIFT_HOST:?Set REDSHIFT_HOST}"
: "${REDSHIFT_PORT:?Set REDSHIFT_PORT}"
: "${REDSHIFT_DATABASE:?Set REDSHIFT_DATABASE}"
: "${REDSHIFT_SCHEMA:?Set REDSHIFT_SCHEMA}"
: "${REDSHIFT_USER:?Set REDSHIFT_USER}"
: "${REDSHIFT_PASSWORD:?Set REDSHIFT_PASSWORD}"
: "${REDSHIFT_SSLMODE:?Set REDSHIFT_SSLMODE}"
: "${DB_THREADS:?Set DB_THREADS}"

oc -n "${OPENSHIFT_NAMESPACE}" create secret generic dbt-demo-redshift \
  --from-literal=DBT_TARGET="${DBT_TARGET}" \
  --from-literal=REDSHIFT_HOST="${REDSHIFT_HOST}" \
  --from-literal=REDSHIFT_PORT="${REDSHIFT_PORT}" \
  --from-literal=REDSHIFT_DATABASE="${REDSHIFT_DATABASE}" \
  --from-literal=REDSHIFT_SCHEMA="${REDSHIFT_SCHEMA}" \
  --from-literal=REDSHIFT_USER="${REDSHIFT_USER}" \
  --from-literal=REDSHIFT_PASSWORD="${REDSHIFT_PASSWORD}" \
  --from-literal=REDSHIFT_SSLMODE="${REDSHIFT_SSLMODE}" \
  --from-literal=DB_THREADS="${DB_THREADS}" \
  --dry-run=client -o yaml \
  | oc apply -f -
