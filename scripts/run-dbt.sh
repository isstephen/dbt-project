#!/usr/bin/env bash
set -euo pipefail

dbt --version
dbt build --project-dir "${DBT_PROJECT_DIR}" --profiles-dir "${DBT_PROFILES_DIR}" --target "${DBT_TARGET:-prod}"
