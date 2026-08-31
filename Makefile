# jolarca-infrastructure — operator hygiene targets.
# Targets degrade gracefully while workstreams (ansible, k8s) are pending.

SHELL := /bin/bash
TF_ENV ?= production
TF_DIR := terraform/environments/$(TF_ENV)

.PHONY: help fmt lint plan test check docs

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-8s %s\n", $$1, $$2}'

fmt: ## Format terraform + yaml in place
	terraform fmt -recursive terraform
	@command -v yamllint >/dev/null || true

lint: ## Static analysis (tflint, checkov, ansible-lint when present)
	@command -v tflint >/dev/null && tflint --recursive terraform || echo "tflint not installed — skipped"
	@command -v checkov >/dev/null && checkov -d terraform --quiet || echo "checkov not installed — skipped"
	@if [ -f ansible/requirements.yml ] && command -v ansible-lint >/dev/null; then \
		ansible-lint ansible; else echo "ansible workstream pending — skipped"; fi

plan: ## terraform init+plan for $(TF_ENV) (read-only; needs env credentials)
	cd $(TF_DIR) && terraform init -backend=false && terraform plan -lock=false

test: ## Molecule tests for ansible roles (pending workstream)
	@if [ -d ansible/roles ] && ls ansible/roles/*/molecule >/dev/null 2>&1; then \
		molecule test --all; else echo "no molecule suites yet — skipped"; fi

check: ## Gate = fmt-check + validate (mirrors CI)
	terraform fmt -check -recursive terraform
	@for d in terraform/environments/*/; do \
		(cd "$$d" && terraform init -backend=false >/dev/null && terraform validate) || exit 1; done
	bash scripts/audit-no-secrets.sh

docs: ## Regenerate module docs if terraform-docs is installed
	@command -v terraform-docs >/dev/null && \
		for m in terraform/modules/*/; do terraform-docs markdown table --output-file README.md "$$m"; done \
		|| echo "terraform-docs not installed — skipped"
