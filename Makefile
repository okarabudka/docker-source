# Build, test and lint the image matrix.
#   make build                       all versions, all flavours, dev + prod
#   make build test VERSIONS="8.5"   one version
REGISTRY ?= ghcr.io/okarabudka/php
VERSIONS ?= 8.1 8.2 8.3 8.4 8.5
FLAVOURS ?= apache fpm fpm-alpine

HADOLINT_IMAGE  := hadolint/hadolint:v2.15.1
SHELLCHECK_IMAGE := koalaman/shellcheck:v0.11.0

empty :=
space := $(empty) $(empty)
comma := ,
IMAGES := $(foreach v,$(VERSIONS),$(foreach f,$(FLAVOURS),$(REGISTRY):$(v)-$(f) $(REGISTRY):$(v)-$(f)-dev))
BAKE_TARGETS := $(subst .,_,$(subst $(REGISTRY):,,$(IMAGES)))

.PHONY: help build test test-go lint sizes

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{ printf "  %-8s %s\n", $$1, $$2 }'

build: ## Build images into the local Docker image store
	PHP_VERSIONS=$(subst $(space),$(comma),$(VERSIONS)) REGISTRY=$(REGISTRY) \
		docker buildx bake --load $(BAKE_TARGETS)

test: ## Run the smoke tests against built images
	tests/smoke.sh $(IMAGES)

test-go: ## Build the Go example image and test it
	docker build -f go/Dockerfile -t go-example:local go/example
	tests/smoke-go.sh go-example:local

lint: ## hadolint for Dockerfiles, shellcheck for scripts
	docker run --rm -i -v "$(CURDIR)/.hadolint.yaml:/.config/hadolint.yaml:ro" $(HADOLINT_IMAGE) < php/Dockerfile
	docker run --rm -i -v "$(CURDIR)/.hadolint.yaml:/.config/hadolint.yaml:ro" $(HADOLINT_IMAGE) < go/Dockerfile
	docker run --rm -v "$(CURDIR):/mnt:ro" -w /mnt $(SHELLCHECK_IMAGE) \
		php/bin/entrypoint php/bin/php-fpm-healthcheck tests/smoke.sh tests/smoke-go.sh

sizes: ## Print the size of each built image
	@docker image ls --format '{{.Repository}}:{{.Tag}}\t{{.Size}}' $(REGISTRY) | sort -V
