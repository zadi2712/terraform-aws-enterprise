.PHONY: help init fmt validate docs test clean examples

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Display this help message
	@echo "$(BLUE)VPC Endpoints Module - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

init: ## Initialize Terraform
	@echo "$(BLUE)Initializing Terraform...$(NC)"
	terraform init

fmt: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	terraform fmt -recursive

fmt-check: ## Check Terraform formatting
	@echo "$(BLUE)Checking Terraform formatting...$(NC)"
	terraform fmt -check -recursive

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	terraform init -backend=false
	terraform validate

docs: ## Generate documentation with terraform-docs
	@echo "$(BLUE)Generating documentation...$(NC)"
	@if command -v terraform-docs >/dev/null 2>&1; then \
		terraform-docs markdown table . > TERRAFORM_DOCS.md; \
		echo "$(GREEN)Documentation generated successfully!$(NC)"; \
	else \
		echo "$(RED)terraform-docs not found. Install it from https://terraform-docs.io/$(NC)"; \
		exit 1; \
	fi

lint: ## Run tflint
	@echo "$(BLUE)Running tflint...$(NC)"
	@if command -v tflint >/dev/null 2>&1; then \
		tflint --init; \
		tflint; \
		echo "$(GREEN)Linting completed!$(NC)"; \
	else \
		echo "$(YELLOW)tflint not found. Install it from https://github.com/terraform-linters/tflint$(NC)"; \
	fi

security: ## Run security checks with tfsec
	@echo "$(BLUE)Running security checks...$(NC)"
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec .; \
		echo "$(GREEN)Security scan completed!$(NC)"; \
	else \
		echo "$(YELLOW)tfsec not found. Install it from https://github.com/aquasecurity/tfsec$(NC)"; \
	fi

test: ## Run Terraform tests
	@echo "$(BLUE)Running Terraform tests...$(NC)"
	@echo "$(YELLOW)Note: Implement tests in tests/ directory$(NC)"

examples: ## List example configurations
	@echo "$(BLUE)Available Examples:$(NC)"
	@echo ""
	@echo "  $(GREEN)basic$(NC)     - Minimal configuration with essential endpoints"
	@echo "  $(GREEN)complete$(NC)  - Full enterprise setup with all endpoints"
	@echo "  $(GREEN)advanced$(NC)  - Custom policies and security configurations"
	@echo ""
	@echo "To use an example:"
	@echo "  cd examples/basic"
	@echo "  cp *.tfvars.example terraform.tfvars"
	@echo "  # Edit terraform.tfvars with your values"
	@echo "  terraform init && terraform plan"

cost: ## Estimate infrastructure costs with infracost
	@echo "$(BLUE)Estimating infrastructure costs...$(NC)"
	@if command -v infracost >/dev/null 2>&1; then \
		infracost breakdown --path .; \
		echo "$(GREEN)Cost estimation completed!$(NC)"; \
	else \
		echo "$(YELLOW)infracost not found. Install it from https://www.infracost.io/$(NC)"; \
	fi

clean: ## Clean Terraform files
	@echo "$(BLUE)Cleaning Terraform files...$(NC)"
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name ".terraform.lock.hcl" -delete
	find . -type f -name "terraform.tfstate*" -delete
	@echo "$(GREEN)Cleanup completed!$(NC)"

all: fmt validate docs lint ## Run all checks (format, validate, docs, lint)
	@echo "$(GREEN)All checks completed successfully!$(NC)"

check: fmt-check validate lint security ## Run all checks without modifying files
	@echo "$(GREEN)All checks passed!$(NC)"
