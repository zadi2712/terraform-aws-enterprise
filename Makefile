.PHONY: help init plan apply destroy validate fmt lint security test clean docs

# Variables
ENV ?= dev
LAYER ?= networking
AWS_REGION ?= us-east-1

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo '${GREEN}Available targets:${NC}'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  ${YELLOW}%-20s${NC} %s\n", $$1, $$2}'

init: ## Initialize Terraform for a layer (ENV=dev LAYER=networking)
	@echo "${GREEN}Initializing Terraform for $(LAYER) in $(ENV)...${NC}"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform init -backend-config=backend.conf -reconfigure

plan: ## Run terraform plan (ENV=dev LAYER=networking)
	@echo "${GREEN}Planning changes for $(LAYER) in $(ENV)...${NC}"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform plan -var-file=terraform.tfvars -out=tfplan

apply: ## Apply terraform changes (ENV=dev LAYER=networking)
	@echo "${GREEN}Applying changes for $(LAYER) in $(ENV)...${NC}"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform apply -var-file=terraform.tfvars

apply-auto: ## Apply changes without confirmation (ENV=dev LAYER=networking)
	@echo "${YELLOW}Auto-applying changes for $(LAYER) in $(ENV)...${NC}"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform apply -var-file=terraform.tfvars -auto-approve

destroy: ## Destroy infrastructure (ENV=dev LAYER=networking)
	@echo "${RED}WARNING: Destroying $(LAYER) in $(ENV)...${NC}"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform destroy -var-file=terraform.tfvars

validate: ## Validate all Terraform configurations
	@echo "${GREEN}Validating Terraform configurations...${NC}"
	@for layer in layers/*/; do \
		echo "Validating $$layer"; \
		cd $$layer && terraform validate && cd ../..; \
	done

fmt: ## Format all Terraform files
	@echo "${GREEN}Formatting Terraform files...${NC}"
	@terraform fmt -recursive

fmt-check: ## Check if Terraform files are formatted
	@echo "${GREEN}Checking Terraform formatting...${NC}"
	@terraform fmt -check -recursive

lint: ## Run tflint on all configurations
	@echo "${GREEN}Linting Terraform configurations...${NC}"
	@tflint --recursive

security: ## Run security scan with tfsec
	@echo "${GREEN}Running security scan...${NC}"
	@tfsec .

test: validate lint security ## Run all tests

deploy-layer: init plan ## Deploy a specific layer (ENV=dev LAYER=networking)
	@echo "${GREEN}Deploying $(LAYER) to $(ENV)...${NC}"
	@$(MAKE) apply ENV=$(ENV) LAYER=$(LAYER)

deploy-all: ## Deploy all layers in order (ENV=dev)
	@echo "${GREEN}Deploying all layers to $(ENV)...${NC}"
	@$(MAKE) deploy-layer ENV=$(ENV) LAYER=networking
	@$(MAKE) deploy-layer ENV=$(ENV) LAYER=security
	@$(MAKE) deploy-layer ENV=$(ENV) LAYER=dns
	@$(MAKE) deploy-layer ENV=$(ENV) LAYER=database
	@$(MAKE) deploy-layer ENV=$(ENV) LAYER=storage
	@$(MAKE) deploy-layer ENV=$(ENV) LAYER=compute
	@$(MAKE) deploy-layer ENV=$(ENV) LAYER=monitoring

output: ## Show outputs for a layer (ENV=dev LAYER=networking)
	@echo "${GREEN}Outputs for $(LAYER) in $(ENV):${NC}"
	@cd layers/$(LAYER)/environments/$(ENV) && terraform output

state-list: ## List resources in state (ENV=dev LAYER=networking)
	@echo "${GREEN}Resources in $(LAYER) state for $(ENV):${NC}"
	@cd layers/$(LAYER)/environments/$(ENV) && terraform state list

state-pull: ## Pull current state (ENV=dev LAYER=networking)
	@echo "${GREEN}Pulling state for $(LAYER) in $(ENV)...${NC}"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform state pull > state-$(shell date +%Y%m%d%H%M).json

graph: ## Generate dependency graph (ENV=dev LAYER=networking)
	@echo "${GREEN}Generating graph for $(LAYER) in $(ENV)...${NC}"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform graph | dot -Tpng > $(LAYER)-$(ENV)-graph.png
	@echo "Graph saved to layers/$(LAYER)/environments/$(ENV)/$(LAYER)-$(ENV)-graph.png"

clean: ## Clean up temporary files
	@echo "${GREEN}Cleaning up...${NC}"
	@find . -type f -name "*.tfplan" -delete
	@find . -type f -name "*.backup" -delete
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@echo "Clean complete"

docs: ## Generate module documentation
	@echo "${GREEN}Generating documentation...${NC}"
	@terraform-docs markdown table --output-file README.md --output-mode inject modules/

setup-backend: ## Create S3 buckets and DynamoDB tables for state management
	@echo "${GREEN}Setting up Terraform backend...${NC}"
	@./scripts/setup-backend.sh

health-check: ## Run health check on environment (ENV=prod)
	@echo "${GREEN}Running health check for $(ENV)...${NC}"
	@./scripts/health-check.sh $(ENV)

cost-estimate: ## Estimate infrastructure costs (ENV=dev LAYER=networking)
	@echo "${GREEN}Estimating costs for $(LAYER) in $(ENV)...${NC}"
	@cd layers/$(LAYER)/environments/$(ENV) && \
		terraform plan -var-file=terraform.tfvars -out=tfplan && \
		infracost breakdown --path tfplan

backup-state: ## Backup all Terraform state files
	@echo "${GREEN}Backing up state files...${NC}"
	@./scripts/backup-terraform-state.sh

install-tools: ## Install required tools (terraform, tflint, tfsec, etc.)
	@echo "${GREEN}Installing required tools...${NC}"
	@./scripts/install-tools.sh

pre-commit-install: ## Install pre-commit hooks
	@echo "${GREEN}Installing pre-commit hooks...${NC}"
	@pre-commit install
	@pre-commit run --all-files

version: ## Show versions of installed tools
	@echo "${GREEN}Tool versions:${NC}"
	@echo "Terraform: $$(terraform version | head -1)"
	@echo "AWS CLI: $$(aws --version)"
	@echo "tflint: $$(tflint --version)"
	@echo "tfsec: $$(tfsec --version)"

# Environment-specific shortcuts
dev-init: ## Initialize dev environment
	@$(MAKE) init ENV=dev LAYER=$(LAYER)

qa-init: ## Initialize QA environment
	@$(MAKE) init ENV=qa LAYER=$(LAYER)

prod-init: ## Initialize production environment
	@$(MAKE) init ENV=prod LAYER=$(LAYER)

dev-deploy: ## Deploy to dev environment
	@$(MAKE) deploy-all ENV=dev

qa-deploy: ## Deploy to QA environment
	@$(MAKE) deploy-all ENV=qa

prod-deploy: ## Deploy to production (requires confirmation)
	@echo "${RED}⚠️  PRODUCTION DEPLOYMENT ⚠️${NC}"
	@echo "You are about to deploy to PRODUCTION"
	@read -p "Type 'DEPLOY-TO-PRODUCTION' to continue: " confirm && [ "$$confirm" = "DEPLOY-TO-PRODUCTION" ]
	@$(MAKE) deploy-all ENV=prod
