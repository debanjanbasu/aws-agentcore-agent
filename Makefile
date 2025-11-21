# Makefile for aws-agentcore-agent

# ====================================================================================
# VARIABLES
# ====================================================================================

# AWS Configuration
AWS_REGION       ?= ap-southeast-2
AWS_ACCOUNT_ID   := $(shell aws sts get-caller-identity --query Account --output text)

# Project Configuration
PROJECT_NAME     := aws-agentcore-agent
ECR_REPO_NAME    ?= $(PROJECT_NAME)-repo
ECR_REPO_URI     := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME)

# Docker Configuration
DOCKER_PLATFORM  ?= linux/arm64 # Default to ARM64 for Graviton

# Terraform State Configuration
export TF_STATE_BUCKET  ?= $(PROJECT_NAME)-tfstate-$(AWS_ACCOUNT_ID)-$(AWS_REGION)

# Colors for output
RED := \033[1;31m
GREEN := \033[1;32m
YELLOW := \033[1;33m
BLUE := \033[1;34m
CYAN := \033[1;36m
BOLD := \033[1m
RESET := \033[0m

# ====================================================================================
# HELP
# ====================================================================================

.PHONY: help
.DEFAULT_GOAL := help

help: ## ✨ Show this help
	@echo "$(CYAN)$(BOLD)AWS Agentcore Agent - Developer Commands$(RESET)"
	@echo ""
	@echo "$(GREEN)Build & Test:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(check-tools|build|release|test|all|update-deps|lint|format):' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Deployment:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(login|push|setup-backend|create-ecr|deploy|tf-destroy):' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Development Tools:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(oauth-config|launch-a2a-inspector|kill-a2a-inspector|clean|logs|update-secrets):' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Terraform Commands:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(tf-init|tf-plan|tf-apply):' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)For full infrastructure commands:$(RESET) $(YELLOW)cd iac && make help$(RESET)"

# ====================================================================================
# TOOLING
# ====================================================================================

check-tools: ## 🔧 Check for required tools (uv, docker, aws-cli)
	@echo "$(BLUE)🔧 Checking required tools...$(RESET)"
	@command -v uv >/dev/null 2>&1 || (echo "$(RED)❌ uv not found. Please install uv: https://github.com/astral-sh/uv$(RESET)" && exit 1)
	@command -v docker >/dev/null 2>&1 || (echo "$(RED)❌ docker not found. Please install docker desktop: https://www.docker.com/products/docker-desktop/$(RESET)" && exit 1)
	@command -v aws >/dev/null 2>&1 || (echo "$(RED)❌ aws-cli not found. Please install aws-cli: https://aws.amazon.com/cli/$(RESET)" && exit 1)
	@echo "$(GREEN)✅ All required tools are installed.$(RESET)"


# ====================================================================================
# BUILD & TEST
# ====================================================================================

.PHONY: build test release all update-deps lint format

build: ## 🐳 Build the Docker image (debug/local build)
	@echo "$(BLUE)🐳 Building Docker image for $(PROJECT_NAME)...$(RESET)"
	@docker build -t $(ECR_REPO_URI):latest .

test: ## 🧪 Run unit tests
	@echo "$(BLUE)🧪 Running unit tests...$(RESET)"
	@uv run python -m pytest tests/ -v
	@echo "$(GREEN)✓ All tests passed!$(RESET)"

release: ## 📦 Build a release-ready Docker image for a specific platform
	@echo "$(BLUE)📦 Building multi-platform Docker image for $(PROJECT_NAME) for platform $(DOCKER_PLATFORM)...$(RESET)"
	@docker buildx build --platform $(DOCKER_PLATFORM) -t $(ECR_REPO_URI):latest .

all: test build ## ✨ Run tests and build the image

update-deps: ## 📦 Update all dependencies to their latest versions
	@echo "$(BLUE)📦 Updating Python dependencies...$(RESET)"
	@uv pip compile pyproject.toml -o uv.lock
	@echo "$(BLUE)📦 Updating Terraform providers...$(RESET)"
	@cd iac && terraform init -upgrade
	@echo "$(GREEN)✅ Dependencies updated!$(RESET)"

lint: ## 🧹 Lint the code
	@echo "$(BLUE)🧹 Linting code...$(RESET)"
	@uv run ruff check .
	@echo "$(GREEN)✓ Linting complete!$(RESET)"

format: ## 💅 Format the code
	@echo "$(BLUE)💅 Formatting code...$(RESET)"
	@uv run black .
	@echo "$(GREEN)✓ Formatting complete!$(RESET)"


# ====================================================================================
# DOCKER & ECR
# ====================================================================================

.PHONY: login push

login: ## 🔑 Authenticate Docker to AWS ECR
	@echo "$(BLUE)🔑 Authenticating Docker to ECR...$(RESET)"
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

push: login release ## 🚀 Build, tag, and push the Docker image to ECR
	@echo "$(BLUE)🚀 Tagging and pushing Docker image to ECR...$(RESET)"
	@docker push $(ECR_REPO_URI):latest


# ====================================================================================
# TERRAFORM & DEPLOYMENT
# ====================================================================================

.PHONY: deploy create-ecr oauth-config tf-init tf-plan tf-apply tf-destroy setup-backend

# Smart Backend Configuration Check
check-backend-config:
	@if [ ! -f iac/backend.config ]; then \
		echo "$(YELLOW)⚠️  backend.config file not found!$(RESET)"; \
		echo ""; \
		echo "You need to run the one-time backend setup first:"; \
		echo "  $(CYAN)make setup-backend$(RESET)"; \
		echo ""; \
		echo "This will:"; \
		echo "  1. Create an S3 bucket for Terraform state"; \
		echo "  2. Enable native S3 state locking (Terraform 1.10+)"; \
		echo "  3. Generate the iac/backend.config file"; \
		echo ""; \
		echo "After setup, run '$(CYAN)make tf-init$(RESET)' to initialize Terraform."; \
		exit 1; \
	else \
		echo "$(GREEN)✅ backend.config file exists$(RESET)"; \
	fi

setup-backend: ## ⚙️ Create S3 backend for Terraform state (native locking)
	@bash -c ' \
	set -e; \
	echo -e "$(BLUE)⚙️  Setting up Terraform backend...$(RESET)"; \
	if [ -f iac/backend.config ]; then \
		echo -e "$(YELLOW)⚠️  A backend configuration already exists:$(RESET)"; \
		echo ""; \
		cat iac/backend.config | sed "s/^/  /"; \
		echo ""; \
		read -p "Do you want to proceed and create a new backend? (y/N): " CONFIRM; \
		if [ "$$CONFIRM" != "y" ] && [ "$$CONFIRM" != "Y" ]; then \
			echo -e "$(GREEN)✅ Aborted. Existing backend preserved.$(RESET)"; \
			exit 0; \
		fi; \
	fi; \
	command -v aws >/dev/null 2>&1 || (echo -e "$(RED)❌ AWS CLI not found. Install: https://aws.amazon.com/cli/$(RESET)" && exit 1); \
	aws sts get-caller-identity >/dev/null 2>&1 || (echo -e "$(RED)❌ AWS CLI not configured. Run: aws configure$(RESET)" && exit 1); \
	read -p "Enter a globally unique S3 bucket name for Terraform state: " BUCKET_NAME; \
	if [ -z "$$BUCKET_NAME" ]; then \
		echo -e "$(RED)❌ Bucket name cannot be empty.$(RESET)"; \
		exit 1; \
	fi; \
	echo -e "$(BLUE)▶️ Creating S3 bucket '\''$$BUCKET_NAME'\'' in region $(AWS_REGION)...$(RESET)"; \
	if aws s3api head-bucket --bucket $$BUCKET_NAME --no-cli-pager 2>/dev/null; then \
		echo -e "$(YELLOW)⚠️  Bucket '\''$$BUCKET_NAME'\'' already exists. Using existing bucket.$(RESET)"; \
	else \
		aws s3api create-bucket --bucket $$BUCKET_NAME --region $(AWS_REGION) --create-bucket-configuration LocationConstraint=$(AWS_REGION) --no-cli-pager > /dev/null; \
	fi; \
	echo -e "$(BLUE)▶️ Enabling versioning and encryption for '\''$$BUCKET_NAME'\''...$(RESET)"; \
	aws s3api put-bucket-versioning --bucket $$BUCKET_NAME --versioning-configuration Status=Enabled > /dev/null; \
	aws s3api put-bucket-encryption --bucket $$BUCKET_NAME --server-side-encryption-configuration '\''{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'\'' > /dev/null; \
	echo -e "$(BLUE)▶️ Creating '\''iac/backend.config'\'' for local use...$(RESET)"; \
	echo "bucket         = \"$$BUCKET_NAME\"" > iac/backend.config; \
	echo "key            = \"aws-agentcore-agent/terraform.tfstate\"" >> iac/backend.config; \
	echo "region         = \"$(AWS_REGION)\"" >> iac/backend.config; \
	echo "use_lockfile   = true" >> iac/backend.config; \
	echo -e "$(GREEN)✅ Backend setup complete!$(RESET)"; \
	echo -e "$(CYAN)ℹ️  Using native S3 state locking (Terraform 1.10+)$(RESET)"; \
	echo -e "Run '\''$(CYAN)make tf-init$(RESET)'\'' to initialize Terraform with the new backend."; \
	echo "TF_BACKEND_BUCKET=\"$$BUCKET_NAME\"" >> .env \
	'

tf-init: check-backend-config ## ⚙️ Initialize Terraform
	@echo "$(BLUE)⚙️  Initializing Terraform...$(RESET)"
	@cd iac && terraform init -backend-config=backend.config

tf-plan: check-backend-config ## 📋 Plan Terraform changes
	@echo "$(BLUE)📋 Planning Terraform deployment...$(RESET)"
	@cd iac && terraform plan

tf-apply: check-backend-config ## 🚀 Apply Terraform changes
	@echo "$(BLUE)🚀 Applying Terraform deployment...$(RESET)"
	@cd iac && terraform apply -auto-approve

tf-destroy: check-backend-config ## 🧨 Destroy Terraform resources
	@echo "$(YELLOW)🧨 Destroying Terraform resources...$(RESET)"
	@cd iac && terraform destroy -auto-approve

deploy: ## 🚀 Push Docker image and apply Terraform changes
	@$(MAKE) check-backend-config
	@$(MAKE) create-ecr
	@echo "$(GREEN)✅ ECR repository $(ECR_REPO_NAME) is ready.$(RESET)"
	@$(MAKE) push
	@$(MAKE) tf-apply
	@echo "$(GREEN)Deployment complete.$(RESET)"

create-ecr: ## 📦 Create ECR repository via Terraform
	@$(MAKE) -C iac create-ecr

oauth-config: ## 📋 Display JWT configuration for A2A authentication
	@$(MAKE) -C iac oauth-config


# ====================================================================================
# UTILITIES
# ====================================================================================

.PHONY: launch-a2a-inspector kill-a2a-inspector logs

launch-a2a-inspector: ## 🚀 Launch the A2A Inspector Docker container
	@echo "$(BLUE)🚀 Cloning and building a2aproject/a2a-inspector Docker image...$(RESET)"
	@git clone https://github.com/a2aproject/a2a-inspector.git /tmp/a2a-inspector || true
	@echo "$(BLUE)🚀 Launching A2A Inspector on http://localhost:8080 in foreground for debugging. Press Ctrl+C to stop.$(RESET)"
	@docker run --rm --name a2a-inspector -p 8080:8080 a2aproject/a2a-inspector
	@echo "$(GREEN)A2A Inspector stopped.$(RESET)"

kill-a2a-inspector: ## 🛑 Stop the A2A Inspector Docker container
	@echo "$(BLUE)🛑 Stopping A2A Inspector Docker container...$(RESET)"
	@docker stop a2a-inspector > /dev/null 2>&1 || true
	@echo "$(GREEN)A2A Inspector stopped.$(RESET)"

logs: ## 📜 Tail CloudWatch logs
	@echo "$(BLUE)📜 Tailing CloudWatch logs...$(RESET)"
	@cd iac && $(MAKE) logs

update-secrets: ## 🔐 Update GitHub repository secrets from .env file
	@echo "$(BLUE)🔐 Updating GitHub repository secrets from .env file...$(RESET)"
	@if [ ! -f .env ]; then \
		echo "$(RED)❌ .env file not found! Create a .env file with your secrets (e.g., MY_SECRET=value).$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Setting secrets for GitHub Actions...$(RESET)"
	@gh secret set -f .env --app actions
	@echo "$(BLUE)Setting secrets for Dependabot...$(RESET)"
	@gh secret set -f .env --app dependabot
	@echo "$(GREEN)✅ GitHub secrets updated for both GitHub Actions and Dependabot!$(RESET)"

# ====================================================================================
# CLEANUP
# ====================================================================================

.PHONY: clean

clean: ## 🧹 Clean up local build artifacts
	@echo "$(BLUE)🧹 Cleaning up local build artifacts...$(RESET)"
	@rm -f iac/.terraform.lock.hcl
	@rm -rf iac/.terraform
	@rm -rf /tmp/a2a-inspector