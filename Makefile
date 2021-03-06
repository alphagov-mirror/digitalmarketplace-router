SHELL := /bin/bash

TEST_CONTAINER_NAME := digitalmarketplace_test_router
TEST_IMAGE_NAME := digitalmarketplace/test-router

.PHONY: -generate-cdn-route-service-conf
-generate-cdn-route-service-conf:
	$(if ${DOMAIN},,$(error Must specify DOMAIN))
	$(eval export CDN_ROUTE_SERVICE_CONF='{"headers": ["*"], "domain": "www.${DOMAIN},api.${DOMAIN},search-api.${DOMAIN},antivirus-api.${DOMAIN},assets.${DOMAIN}"}')

.PHONY: update-cdn-route-service
update-cdn-route-service: -generate-cdn-route-service-conf
	cf update-service router_cdn -c ${CDN_ROUTE_SERVICE_CONF}

.PHONY: create-cdn-route-service
create-cdn-route-service: -generate-cdn-route-service-conf
	cf create-service cdn-route cdn-route router_cdn -c ${CDN_ROUTE_SERVICE_CONF}

.PHONY: docker-build
docker-build:
	$(if ${RELEASE_NAME},,$(eval export RELEASE_NAME=$(shell git describe)))
	@echo "Building a docker image for ${RELEASE_NAME}..."
	docker build -t digitalmarketplace/router .
	docker tag digitalmarketplace/router digitalmarketplace/router:${RELEASE_NAME}

.PHONY: test-nginx
test-nginx:
	@echo "Building a docker image for the current directory..."
	docker build -t ${TEST_IMAGE_NAME} .

	@echo "Remove any existing '${TEST_CONTAINER_NAME}' containers if present"
	@docker rm -f ${TEST_CONTAINER_NAME} || true

	@echo "Starting a docker container for '${TEST_IMAGE_NAME}'..."
	@docker run \
		-e DM_USER_IPS=172.0.0.0 \
		-e DM_DEV_USER_IPS=172.0.0.0 \
		-e DM_ADMIN_USER_IPS=172.0.0.0 \
		-e DM_FRONTEND_URL=http://example.net \
		-e DM_API_URL=http://localhost:5000 \
		-e DM_SEARCH_API_URL=http://localhost:5009 \
		-e DM_ANTIVIRUS_API_URL=http://localhost:5008 \
		-e DM_APP_AUTH=12345678 \
		-e DM_DOCUMENTS_S3_URL=https://example.com \
		-e DM_G7_DRAFT_DOCUMENTS_S3_URL=https://example.com \
		-e DM_AGREEMENTS_S3_URL=https://example.com \
		-e DM_COMMUNICATIONS_S3_URL=https://example.com \
		-e DM_REPORTS_S3_URL=https://example.com \
		-e DM_SUBMISSIONS_S3_URL=https://example.com \
		-e DM_RATE_LIMITING_ENABLED=enabled \
		--name ${TEST_CONTAINER_NAME} \
		-p 8080:8080 \
		-d -t ${TEST_IMAGE_NAME}

	@echo "## Waiting for nginx to start..."

	@docker exec ${TEST_CONTAINER_NAME} timeout 10m sh -c "until (test -s /etc/nginx/nginx.conf && (service nginx status >dev/null || ! nginx -t > /dev/null 2>&1)); do sleep 1; done && nginx -t"

	@echo "## Tearing down test container and image"
	@docker rm -f ${TEST_CONTAINER_NAME}
	@docker image rm ${TEST_IMAGE_NAME}

.PHONY: docker-push
docker-push:
	$(if ${RELEASE_NAME},,$(eval export RELEASE_NAME=$(shell git describe)))
	docker push digitalmarketplace/router:${RELEASE_NAME}

# Python test recipes
VIRTUALENV_ROOT := $(shell [ -z $$VIRTUAL_ENV ] && echo $$(pwd)/venv || echo $$VIRTUAL_ENV)

virtualenv:
	[ -z $$VIRTUAL_ENV ] && [ ! -d venv ] && python3 -m venv venv || true

requirements-dev: virtualenv requirements-dev.txt
	${VIRTUALENV_ROOT}/bin/pip install -r requirements-dev.txt

test: requirements-dev test-flake8 test-python test-nginx

test-flake8: virtualenv
	${VIRTUALENV_ROOT}/bin/flake8 .

test-python: virtualenv
	${VIRTUALENV_ROOT}/bin/py.test ${PYTEST-ARGS}
