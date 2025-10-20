################################################################################
# Makefile for Enterprise AWS Terraform Infrastructure
# Description: Convenient commands for managing infrastructure
################################################################################

.PHONY: help init plan apply destroy validate fmt lint clean test docs drift-check drift-check-all drift-check-prod drift-report drift-fix

################################################################################
# Drift Detection Targets
################################################################################

drift-check:
	@echo "🔍 Running drift detection for $(LAYER)/$(ENV)..."
	@./scripts/drift-detection.sh $(LAYER) $(ENV)

drift-check-all:
	@echo "🔍 Running comprehensive drift detection..."
	@./scripts/drift-detection.sh all all

drift-check-prod:
	@echo "🔍 Running drift detection for production..."
	@./scripts/drift-detection.sh all prod

drift-report:
	@echo "📊 Drift Detection Reports:"
	@echo ""
	@if [ -d "drift-reports" ]; then \
		ls -lht drift-reports/*.txt 2>/dev/null | head -10 || echo "  No drift reports found"; \
		echo ""; \
		echo "View changelog: cat drift-reports/CHANGELOG.md"; \
	else \
		echo "  No drift reports directory found"; \
	fi

drift-fix:
	@echo "⚙️ Applying Terraform to fix drift in $(LAYER)/$(ENV)..."
	@cd layers/$(LAYER)/environments/$(ENV) && terraform apply -auto-approve

drift-help:
	@echo "Drift Detection Commands:"
	@echo "  make drift-check LAYER=compute ENV=prod  - Check specific layer/environment"
	@echo "  make drift-check-all                      - Check all infrastructure"
	@echo "  make drift-check-prod                     - Check production only"
	@echo "  make drift-report                         - View drift reports"
	@echo "  make drift-fix LAYER=x ENV=y              - Fix drift (apply Terraform)"
	@echo ""
	@echo "Examples:"
	@echo "  make drift-check LAYER=security ENV=prod"
	@echo "  make drift-check-all"
	@echo "  ./scripts/drift-detection.sh compute prod"

################################################################################
# Existing Targets
################################################################################

.PHONY: help init plan apply destroy validate fmt lint clean test docs

# Default target
.DEFAULT_GOAL := help

# Variables
ENV ?= dev
LAYER ?= networking
AWS_REGION ?= us-east-1

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

##@ General

help: ## Display this help message
	@echo "$(BLUE)Enterprise AWS Terraform Infrastructure$(NC)"
	@echo ""
	@echo "$(GREEN)Usage:$(NC)"
	@echo "  make <target> [ENV=<environment>] [LAYER=<layer>]"
	@echo ""
	@echo "$(GREEN)Environments:$(NC) dev, qa, uat, prod"
	@echo "$(GREEN)Layers:$(NC) networking, security, dns, database, storage, compute, monitoring"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup

setup-backend: ## Create S3 bucket and DynamoDB table for state
	@echo "$(BLUE)Setting up Terraform backend...$(NC)"
	@./scripts/setup-backend.sh $(ENV)

configure-aws: ## Configure AWS CLI credentials
	@echo "$(BLUE)Configuring AWS CLI...$(NC)"
	@aws configure

check-prereqs: ## Check if required tools are installed
	@echo "$(BLUE)Checking prerequisites...$(NC)"
	@command -v terraform >/dev/null 2>&1 || { echo "$(YELLOW)terraform not found$(NC)"; exit 1; }
	@command -v aws >/dev/null 2>&1 || { echo "$(YELLOW)aws-cli not found$(NC)"; exit 1; }
	@echo "$(GREEN)✅ All prerequisites installed$(NC)"

##@ Development

init: ## Initialize Terraform for a layer
	@echo "$(BLUE)Initializing $(LAYER) layer for $(ENV)...$(NC)"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform init -backend-config=backend.conf -reconfigure

plan: ## Run Terraform plan for a layer
	@echo "$(BLUE)Planning $(LAYER) layer for $(ENV)...$(NC)"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform plan -var-file=terraform.tfvars

apply: ## Apply Terraform changes for a layer
	@echo "$(BLUE)Applying $(LAYER) layer for $(ENV)...$(NC)"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform apply -var-file=terraform.tfvars

destroy: ## Destroy resources for a layer
	@echo "$(YELLOW)⚠️  Destroying $(LAYER) layer for $(ENV)...$(NC)"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform destroy -var-file=terraform.tfvars

output: ## Show outputs for a layer
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform output

##@ Full Deployment

deploy-all: ## Deploy all layers for an environment
	@echo "$(BLUE)Deploying all layers to $(ENV)...$(NC)"
	@./deploy.sh $(ENV)

destroy-all: ## Destroy all layers for an environment
	@echo "$(YELLOW)Destroying all layers in $(ENV)...$(NC)"
	@./destroy.sh $(ENV)

##@ Code Quality

validate: ## Validate all Terraform configurations
	@echo "$(BLUE)Validating Terraform configurations...$(NC)"
	@find layers -name "*.tf" -exec dirname {} \; | sort -u | while read dir; do \
		echo "Validating $$dir..."; \
		(cd "$$dir" && terraform init -backend=false > /dev/null 2>&1 && terraform validate); \
	done

fmt: ## Format all Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	@terraform fmt -recursive

lint: ## Lint Terraform code with tflint
	@echo "$(BLUE)Linting Terraform code...$(NC)"
	@find layers -name "*.tf" -exec dirname {} \; | sort -u | while read dir; do \
		echo "Linting $$dir..."; \
		(cd "$$dir" && tflint); \
	done

security-scan: ## Run security scan with tfsec
	@echo "$(BLUE)Running security scan...$(NC)"
	@tfsec .

##@ Testing

test: ## Run basic tests
	@echo "$(BLUE)Running tests...$(NC)"
	@./scripts/test.sh $(ENV)

validate-env: ## Validate deployed environment
	@echo "$(BLUE)Validating $(ENV) environment...$(NC)"
	@./scripts/validate.sh $(ENV)

##@ Utilities

clean: ## Clean temporary files
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.tfstate" -exec rm -f {} + 2>/dev/null || true
	@find . -type f -name "*.tfstate.backup" -exec rm -f {} + 2>/dev/null || true
	@find . -type f -name ".terraform.lock.hcl" -exec rm -f {} + 2>/dev/null || true
	@find . -type f -name "tfplan" -exec rm -f {} + 2>/dev/null || true
	@echo "$(GREEN)✅ Cleaned$(NC)"

docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@terraform-docs markdown table --output-file README.md --output-mode inject ./modules/vpc
	@echo "$(GREEN)✅ Documentation updated$(NC)"

graph: ## Generate dependency graph
	@echo "$(BLUE)Generating dependency graph...$(NC)"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform graph | dot -Tpng > graph.png && \
		echo "$(GREEN)Graph saved to graph.png$(NC)"

cost-estimate: ## Estimate costs with infracost
	@echo "$(BLUE)Estimating costs for $(ENV)...$(NC)"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		infracost breakdown --path .

##@ Monitoring

logs: ## Show deployment logs
	@tail -f logs/deploy-$(ENV)-*.log

outputs: ## Show all outputs for environment
	@echo "$(BLUE)Outputs for $(ENV):$(NC)"
	@cat outputs/$(ENV)-*-outputs.json 2>/dev/null || echo "No outputs found"

state-list: ## List resources in state
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform state list

##@ Emergency

rollback: ## Rollback to previous state
	@echo "$(YELLOW)⚠️  Rolling back $(LAYER) in $(ENV)...$(NC)"
	@./scripts/rollback.sh $(ENV) $(LAYER)

unlock: ## Force unlock Terraform state (use with caution)
	@echo "$(YELLOW)⚠️  Force unlocking state...$(NC)"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform force-unlock $(LOCK_ID)

##@ Information

show: ## Show current state
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform show

resources: ## Count resources by layer
	@echo "$(BLUE)Resources by layer:$(NC)"
	@for layer in networking security dns database storage compute monitoring; do \
		count=$$(cd layers/$$layer/environments/$(ENV) 2>/dev/null && terraform state list 2>/dev/null | wc -l || echo 0); \
		echo "  $$layer: $$count"; \
	done

version: ## Show versions
	@echo "$(BLUE)Tool versions:$(NC)"
	@echo "Terraform: $$(terraform version -json | jq -r '.terraform_version')"
	@echo "AWS CLI: $$(aws --version | cut -d' ' -f1 | cut -d'/' -f2)"

##@ Quick Commands

dev-deploy: ## Quick deploy to dev
	@$(MAKE) deploy-all ENV=dev

dev-destroy: ## Quick destroy dev
	@$(MAKE) destroy-all ENV=dev

prod-deploy: ## Deploy to production (with confirmations)
	@$(MAKE) deploy-all ENV=prod

list-envs: ## List all environments
	@echo "$(BLUE)Available environments:$(NC)"
	@for env in dev qa uat prod; do \
		echo "  - $$env"; \
	done

list-layers: ## List all layers
	@echo "$(BLUE)Available layers:$(NC)"
	@for layer in networking security dns database storage compute monitoring; do \
		echo "  - $$layer"; \
	done
