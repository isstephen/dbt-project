SHELL := /bin/bash

.PHONY: build push deploy create-secrets validate

build:
	./scripts/build-and-push.sh build-only

push:
	./scripts/build-and-push.sh

deploy:
	./scripts/deploy-openshift.sh

create-secrets:
	./scripts/create-db-secret.sh
	./scripts/create-ecr-pull-secret.sh

validate:
	docker run --rm --entrypoint dbt "$${AWS_ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com/$${ECR_REPOSITORY}:$${IMAGE_TAG}" --version
