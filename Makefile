SHELL := /bin/bash
include ci/upstream.env
export

IMAGE_REF ?= $(IMAGE_NAME):$(UPSTREAM_REF)

.PHONY: help bootstrap restore build test test-integration blackbox coverage coverage-report sonar publish image sbom trivy owasp push deploy-appservice deploy-aks ci lint-helm clean distclean

help:
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

bootstrap: ## fetch upstream at the pinned SHA
	./ci/bootstrap.sh

restore: bootstrap ## dotnet restore through the configured feed
	./ci/restore.sh

build: ## dotnet build -c Release --no-restore
	./ci/build.sh

test: ## unit tests + coverlet cobertura
	./ci/test-unit.sh

coverage: ## enforce the line-coverage gate
	./ci/coverage-gate.sh

coverage-report: ## print the coverage table
	./ci/coverage-report.sh

test-integration: ## upstream integration suite (needs docker)
	./ci/test-integration.sh

blackbox: ## black-box suite against IMAGE_REF
	IMAGE_REF=$(IMAGE_REF) ./ci/test-blackbox.sh

sonar: ## sonarcloud analysis + quality gate
	./ci/sonar.sh

publish: ## dotnet publish into .out/app
	./ci/publish.sh

image: ## build the runtime image
	IMAGE_REF=$(IMAGE_REF) ./ci/image.sh

sbom: ## cyclonedx + spdx sbom
	./ci/sbom.sh

trivy: ## trivy fs + image scan
	./ci/scan-trivy.sh

owasp: ## owasp dependency-check on the NuGet graph
	./ci/scan-owasp.sh

push: ## tag and push to $(REGISTRY)
	IMAGE_REF=$(IMAGE_REF) ./ci/push.sh

deploy-appservice: ## set the digest-pinned image on Azure App Service
	./ci/deploy-appservice.sh

deploy-aks: ## helm upgrade --install onto the current kube context
	./ci/deploy-aks.sh

lint-helm: ## helm lint + template
	helm lint helm/orchardcore
	helm template cms helm/orchardcore -f helm/orchardcore/values-prod.yaml > /dev/null

ci: restore build test coverage publish image sbom trivy blackbox ## the whole pipeline, locally

clean: ## drop build outputs, keep upstream and the package cache
	rm -rf .out

distclean: clean ## drop upstream and the package cache too
	rm -rf $(UPSTREAM_DIR) .nuget .cache
