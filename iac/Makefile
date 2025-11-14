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
		echo "✅ backend.config already exists. Skipping backend setup."; \
		exit 0; \
	fi; \
	if [ -z "$(TF_STATE_BUCKET)" ]; then \
		read -p "Enter a globally unique S3 bucket name for Terraform state: " BUCKET_NAME; \
	else \
		BUCKET_NAME="$(TF_STATE_BUCKET)"; \
		echo "Using provided TF_STATE_BUCKET: $$BUCKET_NAME"; \
	fi; \
	if [ -z "$$BUCKET_NAME" ]; then \
		echo "❌ Bucket name cannot be empty."; \
		exit 1; \
	fi; \
	DYNAMODB_TABLE="terraform-state-lock-$(PROJECT_NAME)"; \
	if aws s3api head-bucket --bucket $$BUCKET_NAME --region $(AWS_REGION) 2>/dev/null; then \
		echo "▶️ S3 bucket '$$BUCKET_NAME' already exists. Skipping creation."; \
	else \
		echo "▶️ Creating S3 bucket '$$BUCKET_NAME' in region $(AWS_REGION)..."; \
		aws s3api create-bucket --bucket $$BUCKET_NAME --region $(AWS_REGION) --create-bucket-configuration LocationConstraint=$(AWS_REGION) > /dev/null; \
	fi; \
	echo "▶️ Enabling versioning and encryption for '$$BUCKET_NAME'..."; \
	aws s3api put-bucket-versioning --bucket $$BUCKET_NAME --versioning-configuration Status=Enabled > /dev/null; \
	aws s3api put-bucket-encryption --bucket $$BUCKET_NAME --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' > /dev/null; \
	if aws dynamodb describe-table --table-name $$DYNAMODB_TABLE --region $(AWS_REGION) 2>/dev/null; then \
		echo "▶️ DynamoDB table '$$DYNAMODB_TABLE' already exists. Skipping creation."; \
	else \
		echo "▶️ Creating DynamoDB table '$$DYNAMODB_TABLE' for state locking..."; \
		aws dynamodb create-table \
			--table-name $$DYNAMODB_TABLE \
			--attribute-definitions AttributeName=LockID,AttributeType=S \
			--key-schema AttributeName=LockID,KeyType=HASH \
			--provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
			--region $(AWS_REGION) > /dev/null; \
	fi; \
	echo "▶️ Creating 'backend.config' for local use..."; \
	echo "bucket         = \"$$BUCKET_NAME\"" > backend.config; \
	echo "key            = \"$(PROJECT_NAME)/terraform.tfstate\"" >> backend.config; \
	echo "region         = \"$(AWS_REGION)\"" >> backend.config; \
	echo "dynamodb_table = \"$$DYNAMODB_TABLE\"" >> backend.config; \
	echo "✅ Backend setup complete!"; \
	echo "Run 'make tf-init' to initialize Terraform with the new backend."


tf-init: ## Initialize Terraform
	@echo "Initializing Terraform..."
	@terraform init -backend-config=backend.config

plan: tf-init ## Plan Terraform changes
	@echo "Planning Terraform deployment..."
	@terraform plan $(ARGS)

apply: tf-init ## Apply Terraform changes
	@echo "Applying Terraform deployment..."
	@terraform apply -auto-approve $(ARGS) -var="terraform_state_bucket_name=$(TF_STATE_BUCKET)"

destroy: ## Destroy Terraform resources
	@echo "Destroying Terraform resources..."
	@terraform destroy -auto-approve $(ARGS)

test: ## 🧪 Validate and plan Terraform configuration
	@$(MAKE) tf-validate
	@$(MAKE) tf-plan

create-ecr: ## 📦 Create ECR repository via Terraform
	@echo "Creating ECR repository if it doesn't exist..."
	@terraform apply -auto-approve -target=aws_ecr_repository.agentcore_repo -var="terraform_state_bucket_name=$(TF_STATE_BUCKET)"



oauth-config: ## 📋 Display JWT configuration for A2A authentication
	@echo "=== A2A JWT Authentication Configuration ==="
	@echo ""
	@bash -c ' \
		CLIENT_ID=$$(terraform output -raw entra_app_client_id 2>/dev/null); \
		TENANT_ID=$$(terraform output -raw entra_tenant_id 2>/dev/null); \
		if [ -z "$$CLIENT_ID" ] || [ -z "$$TENANT_ID" ]; then \
			echo "❌ Error: Terraform outputs not available. Run \"make tf-apply\" first."; \
			exit 1; \
		fi; \
		echo "📋 Use these values to configure your A2A client for JWT authentication:"; \
		echo ""; \
		echo "  Client ID: $$CLIENT_ID"; \
		echo "  Tenant ID: $$TENANT_ID"; \
		echo "  Authorization URL: https://login.microsoftonline.com/$$TENANT_ID/oauth2/v2.0/authorize"; \
		echo "  Token URL: https://login.microsoftonline.com/$$TENANT_ID/oauth2/v2.0/token"; \
		echo "  Scope: api://$$CLIENT_ID/access_as_user"; \
		echo ""; \
	'
