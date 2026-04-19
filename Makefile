.DEFAULT_GOAL := help

# Run commands through the mise-managed uv-managed virtualenv.
TF := mise exec -- terraform
UV  := mise exec -- uv
RUN := $(UV) run

# Platforms to generate Terraform provider lock entries for.
TF_PLATFORMS := -platform=darwin_arm64 -platform=linux_amd64

# ── Help ──────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show available make targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# ── Linting ───────────────────────────────────────────────────────────────────

.PHONY: lint
lint: ## Run all linters via pre-commit (yamllint, shellcheck, actionlint, terraform, …)
	$(RUN) pre-commit run --all-files

# ── Install ───────────────────────────────────────────────────────────────────

.PHONY: install
install: ## Install Python dev dependencies via uv
	$(UV) sync --frozen

# ── First-time dev environment initialization ────────────────────────────────

.PHONY: init-dev-env
init-dev-env: install ## Initialize dev environment: install deps and enable git hooks
	$(RUN) pre-commit install
	$(RUN) pre-commit install --hook-type commit-msg

# ── Update UV lock file ───────────────────────────────────────────────────────

.PHONY: lock
lock: ## Regenerate uv.lock from pyproject.toml
	$(UV) lock

# ── Terraform lock files ──────────────────────────────────────────────────────

.PHONY: terraform-lock
terraform-lock: ## Regenerate Terraform lock files for macOS (arm64) and Linux (amd64)
	$(TF) -chdir=src/terraform providers lock $(TF_PLATFORMS)
	$(TF) -chdir=src/terraform/bootstrap providers lock $(TF_PLATFORMS)
