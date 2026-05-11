FROM python:3.12-slim-bookworm AS runtime

ARG APP_UID=10001
ARG APP_GID=10001

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    DBT_PROFILES_DIR=/app/dbt \
    DBT_PROJECT_DIR=/app/dbt \
    DBT_TARGET_PATH=/tmp/dbt-target \
    DBT_LOG_PATH=/tmp/dbt-logs

WORKDIR /app

RUN groupadd --gid "${APP_GID}" dbt \
    && useradd --uid "${APP_UID}" --gid "${APP_GID}" --create-home --shell /usr/sbin/nologin dbt \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /tmp/dbt-target /tmp/dbt-logs \
    && chown -R dbt:dbt /app /tmp/dbt-target /tmp/dbt-logs

COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip install -r requirements.txt

COPY --chown=dbt:dbt dbt ./dbt
COPY --chown=dbt:dbt scripts/run-dbt.sh /usr/local/bin/run-dbt.sh

RUN dbt deps --project-dir /app/dbt --profiles-dir /app/dbt \
    && chown -R dbt:dbt /app/dbt \
    && chmod 0555 /usr/local/bin/run-dbt.sh

USER dbt

WORKDIR /app/dbt
ENTRYPOINT ["/usr/local/bin/run-dbt.sh"]
