.PHONY: help login tf-init create-ecr test oauth-config plan apply destroy setup-backend logs clean

# ====================================================================================
# VARIABLES
# ====================================================================================

AWS_REGION   ?= ap-southeast-2
PROJECT_NAME ?= aws-agentcore-agent
ARGS         ?=

# Colors for output
RED := \033[1;31m
GREEN := \033[1;32m
YELLOW := \033[1;33m
BLUE := \033[1;34m
CYAN := \033[1;36m
BOLD := \033[1m
RESET := \033[0m

# ====================================================================================
# HELPERS
# ====================================================================================

.PHONY: help
.DEFAULT_GOAL := help

help: ## ✨ Show this help
	@echo "$(CYAN)$(BOLD)AWS Agentcore Agent - Infrastructure Commands$(RESET)"
	@echo ""
	@echo "$(GREEN)Quick Start:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "}; /^apply:.*##/ {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Step by Step:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "}; /^(setup-backend|tf-init|plan|apply):.*##/ {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Testing:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "}; /^(logs|test):.*##/ {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Utilities:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "}; /^(login|clean|destroy|oauth-config):.*##/ {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ====================================================================================
# UTILITIES
# ====================================================================================

login: ## 🔐 Authenticate AWS + Azure CLIs
	@echo "$(BLUE)🔐 Authenticating with AWS and Azure...$(RESET)"
	@command -v aws >/dev/null 2>&1 || (echo "$(RED)❌ AWS CLI not found. Install: https://aws.amazon.com/cli/$(RESET)" && exit 1)
	@command -v az >/dev/null 2>&1 || (echo "$(RED)❌ Azure CLI not found. Install: https://aka.ms/azure-cli$(RESET)" && exit 1)

	@if aws sts get-caller-identity >/dev/null 2>&1; then \
		echo "$(GREEN)✅ AWS: $$(aws sts get-caller-identity --query 'Account' --output text)$(RESET)"; \
	else \
		echo "Please login to AWS:"; \
		if aws configure list | grep -q sso_start_url; then \
			aws sso login; \
		else \
			echo "Run: aws configure"; \
			exit 1; \
		fi; \
	fi

	@if az account show >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Azure: $$(az account show --query 'name' -o tsv)$(RESET)"; \
	else \
		echo "Logging into Azure..."; \
		az login; \
	fi
	@echo "$(GREEN)✅ Authentication complete!$(RESET)"

clean: ## 🧹 Remove tokens and backups
	@echo "$(BLUE)🧹 Cleaning up temporary files...$(RESET)"
	@rm -f .env
	@rm -f terraform.tfvars.*.backup
	@rm -f terraform.tfvars.temp
	@echo "$(GREEN)✅ Clean complete!$(RESET)"

# ====================================================================================
# TERRAFORM COMMANDS
# ====================================================================================

setup-backend: ## ⚙️ Create S3 backend for Terraform state (deprecated - use root Makefile)
	@if [ -f backend.config ]; then \
		echo "\033[1;32m✅ backend.config already exists. Skipping backend setup.\033[0m"; \
		exit 0; \
	fi; \
	if [ -z "$(TF_STATE_BUCKET)" ]; then \
		read -p "\033[1;34mEnter a globally unique S3 bucket name for Terraform state: \033[0m" BUCKET_NAME; \
	else \
		BUCKET_NAME="$(TF_STATE_BUCKET)"; \
		echo "\033[1;34mUsing provided TF_STATE_BUCKET: $$BUCKET_NAME\033[0m"; \
	fi; \
	if [ -z "$$BUCKET_NAME" ]; then \
		echo "\033[1;31m❌ Bucket name cannot be empty.\033[0m"; \
		exit 1; \
	fi; \
	DYNAMODB_TABLE="terraform-state-lock-$(PROJECT_NAME)"; \
	if aws s3api head-bucket --bucket $$BUCKET_NAME --region $(AWS_REGION) 2>/dev/null; then \
		echo "\033[1;34m▶️ S3 bucket '$$BUCKET_NAME' already exists. Skipping creation.\033[0m"; \
	else \
		echo "\033[1;34m▶️ Creating S3 bucket '$$BUCKET_NAME' in region $(AWS_REGION)...\033[0m"; \
		aws s3api create-bucket --bucket $$BUCKET_NAME --region $(AWS_REGION) --create-bucket-configuration LocationConstraint=$(AWS_REGION) > /dev/null; \
	fi; \
	echo "\033[1;34m▶️ Enabling versioning and encryption for '$$BUCKET_NAME'...\033[0m"; \
	aws s3api put-bucket-versioning --bucket $$BUCKET_NAME --versioning-configuration Status=Enabled > /dev/null; \
	aws s3api put-bucket-encryption --bucket $$BUCKET_NAME --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' > /dev/null; \
	if aws dynamodb describe-table --table-name $$DYNAMODB_TABLE --region $(AWS_REGION) 2>/dev/null; then \
		echo "\033[1;34m▶️ DynamoDB table '$$DYNAMODB_TABLE' already exists. Skipping creation.\033[0m"; \
	else \
		echo "\033[1;34m▶️ Creating DynamoDB table '$$DYNAMODB_TABLE' for state locking...\033[0m"; \
		aws dynamodb create-table \
			--table-name $$DYNAMODB_TABLE \
			--attribute-definitions AttributeName=LockID,AttributeType=S \
			--key-schema AttributeName=LockID,KeyType=HASH \
			--provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
			--region $(AWS_REGION) > /dev/null; \
	fi; \
	echo "\033[1;34m▶️ Creating 'backend.config' for local use...\033[0m"; \
	echo "bucket         = \"$$BUCKET_NAME\"" > backend.config; \
	echo "key            = \"$(PROJECT_NAME)/terraform.tfstate\"" >> backend.config; \
	echo "region         = \"$(AWS_REGION)\"" >> backend.config; \
	echo "dynamodb_table = \"$$DYNAMODB_TABLE\"" >> backend.config; \
	echo "\033[1;32m✅ Backend setup complete!\033[0m"; \
	echo "Run '\033[1;36mmake tf-init\033[0m' to initialize Terraform with the new backend."


tf-init: ## ⚙️ Initialize Terraform
	@echo "$(BLUE)⚙️  Initializing Terraform...$(RESET)"
	@terraform init -reconfigure -backend-config=backend.config

tf-validate: ## ✅ Validate Terraform configuration
	@echo "$(BLUE)✅ Validating Terraform configuration...$(RESET)"
	@terraform validate

plan: tf-init ## 📋 Plan Terraform changes
	@echo "$(BLUE)📋 Planning Terraform deployment...$(RESET)"
	@terraform plan $(ARGS)

apply: tf-init ## 🚀 Apply Terraform changes
	@echo "$(BLUE)🚀 Applying Terraform deployment...$(RESET)"
	@terraform apply -auto-approve $(ARGS)
	@echo "$(GREEN)✅ Infrastructure changes applied successfully!$(RESET)"

destroy: ## 🧨 Destroy Terraform resources
	@echo "$(YELLOW)🧨 Destroying Terraform resources...$(RESET)"
	@terraform destroy -auto-approve $(ARGS)

test: ## 🧪 Validate and plan Terraform configuration
	@$(MAKE) tf-validate
	@$(MAKE) plan

create-ecr: tf-init ## 📦 Create ECR repository via Terraform
	@echo "$(BLUE)📦 Creating ECR repository if it doesn't exist...$(RESET)"
	@terraform apply -auto-approve -target=aws_ecr_repository.agentcore_repo



oauth-config: ## 📋 Display JWT configuration for A2A authentication
	@echo "$(BLUE)=== A2A JWT Authentication Configuration ===$(RESET)"
	@echo ""
	@bash -c ' \
		CLIENT_ID=$$(terraform output -raw entra_app_client_id 2>/dev/null); \
		TENANT_ID=$$(terraform output -raw entra_tenant_id 2>/dev/null); \
		if [ -z "$$CLIENT_ID" ] || [ -z "$$TENANT_ID" ]; then \
			echo -e "$(RED)❌ Error: Terraform outputs not available. Run \"make apply\" first.$(RESET)"; \
			exit 1; \
		fi; \
		echo -e "$(BLUE)📋 Use these values to configure your A2A client for JWT authentication:$(RESET)"; \
		echo ""; \
		echo -e "  $(CYAN)Client ID:$(RESET) $$CLIENT_ID"; \
		echo -e "  $(CYAN)Tenant ID:$(RESET) $$TENANT_ID"; \
		echo -e "  $(CYAN)Authorization URL:$(RESET) https://login.microsoftonline.com/$$TENANT_ID/oauth2/v2.0/authorize"; \
		echo -e "  $(CYAN)Token URL:$(RESET) https://login.microsoftonline.com/$$TENANT_ID/oauth2/v2.0/token"; \
		echo -e "  $(CYAN)Scope:$(RESET) api://$$CLIENT_ID/access_as_user"; \
		echo ""; \
	'

logs: ## 📜 Tail CloudWatch logs
	@echo "$(BLUE)📜 Tailing CloudWatch logs... (Ctrl+C to exit)$(RESET)"
	@bash -c ' \
		set -e; \
		LOG_GROUP_NAME=$$(terraform output -raw log_group_name 2>/dev/null); \
		if [ -z "$$LOG_GROUP_NAME" ]; then \
			echo -e "$(RED)❌ Error: Log group name not found in Terraform outputs. Run \"make apply\" first.$(RESET)"; \
			exit 1; \
		fi; \
		echo "Found log group: $$LOG_GROUP_NAME"; \
		aws logs tail $$LOG_GROUP_NAME --follow --region $(AWS_REGION); \
	'
