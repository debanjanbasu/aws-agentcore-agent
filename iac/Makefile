.PHONY: help tf-init create-ecr test oauth-config plan apply destroy setup-backend

# ====================================================================================
# VARIABLES
# ====================================================================================

AWS_REGION   ?= ap-southeast-2
PROJECT_NAME ?= aws-agentcore-agent
ARGS         ?= 
 

# ====================================================================================
# HELPERS
# ====================================================================================

.PHONY: help
.DEFAULT_GOAL := help

help: ## Show this help
	@echo "IAC Makefile - Terraform Infrastructure"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ====================================================================================
# TERRAFORM COMMANDS
# ====================================================================================

setup-backend: ## Create S3/DynamoDB backend for Terraform state
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


tf-init: ## Initialize Terraform
	@echo "\033[1;34m⚙️  Initializing Terraform...\033[0m"
	@terraform init -reconfigure -backend-config=backend.config

tf-validate: ## Validate Terraform configuration
	@echo "\033[1;34m✅ Validating Terraform configuration...\033[0m"
	@terraform validate

plan: tf-init ## Plan Terraform changes
	@echo "\033[1;34m📋 Planning Terraform deployment...\033[0m"
	@terraform plan $(ARGS)

apply: tf-init ## Apply Terraform changes
	@echo "\033[1;34m🚀 Applying Terraform deployment...\033[0m"
	@terraform apply -auto-approve $(ARGS) -var="terraform_state_bucket_name=$(TF_STATE_BUCKET)"

destroy: ## Destroy Terraform resources
	@echo "\033[1;33m🧨 Destroying Terraform resources...\033[0m"
	@terraform destroy -auto-approve $(ARGS)

test: ## 🧪 Validate and plan Terraform configuration
	@$(MAKE) tf-validate
	@$(MAKE) tf-plan

create-ecr: ## 📦 Create ECR repository via Terraform
	@echo "\033[1;34m📦 Creating ECR repository if it doesn't exist...\033[0m"
	@$(MAKE) tf-init # Explicitly call tf-init with -reconfigure
	@terraform apply -auto-approve -target=aws_ecr_repository.agentcore_repo -var="terraform_state_bucket_name=$(TF_STATE_BUCKET)"



oauth-config: ## 📋 Display JWT configuration for A2A authentication
	@echo "\033[1;34m=== A2A JWT Authentication Configuration ===\033[0m"
	@echo ""
	@bash -c ' \
		CLIENT_ID=$$(terraform output -raw entra_app_client_id 2>/dev/null); \
		TENANT_ID=$$(terraform output -raw entra_tenant_id 2>/dev/null); \
		if [ -z "$$CLIENT_ID" ] || [ -z "$$TENANT_ID" ]; then \
			echo "\033[1;31m❌ Error: Terraform outputs not available. Run \"make tf-apply\" first.\033[0m"; \
			exit 1; \
		fi; \
		echo "\033[1;34m📋 Use these values to configure your A2A client for JWT authentication:\033[0m"; \
		echo ""; \
		echo "  \033[1;36mClient ID:\033[0m $$CLIENT_ID"; \
		echo "  \033[1;36mTenant ID:\033[0m $$TENANT_ID"; \
		echo "  \033[1;36mAuthorization URL:\033[0m https://login.microsoftonline.com/$$TENANT_ID/oauth2/v2.0/authorize"; \
		echo "  \033[1;36mToken URL:\033[0m https://login.microsoftonline.com/$$TENANT_ID/oauth2/v2.0/token"; \
		echo "  \033[1;36mScope:\033[0m api://$$CLIENT_ID/access_as_user"; \
		echo ""; \
	'
