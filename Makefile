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

# Smart Backend Configuration Check
check-backend-config:
	@if [ ! -f iac/backend.config ]; then \
		echo "\033[1;33m⚠️  backend.config file not found!\033[0m"; \
		echo ""; \
		echo "You need to run the one-time backend setup first:"; \
		echo "  \033[1;36mmake setup-backend\033[0m"; \
		echo ""; \
		echo "This will:"; \
		echo "  1. Create an S3 bucket for Terraform state"; \
		echo "  2. Create a DynamoDB table for state locking"; \
		echo "  3. Generate the iac/backend.config file"; \
		echo ""; \
		echo "After setup, run '\033[1;36mmake tf-init\033[0m' to initialize Terraform."; \
		exit 1; \
	else \
		echo "\033[1;32m✅ backend.config file exists\033[0m"; \
	fi

# ====================================================================================
# HELP
# ====================================================================================

.PHONY: help
.DEFAULT_GOAL := help

help: ## ✨ Show this help
	@echo "\033[1;36mAWS Agentcore Agent - Developer Commands\033[0m"
	@echo ""
	@echo "\033[1;32mBuild & Test:\033[0m"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(build|release|test|all|update-deps):' | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "\033[1;32mDeployment:\033[0m"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(login|push|setup-backend|create-ecr|deploy|tf-destroy):' | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "\033[1;32mDevelopment Tools:\033[0m"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(oauth-config|launch-a2a-inspector|kill-a2a-inspector|clean|logs):' | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "\033[1;32mTerraform Commands:\033[0m"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(tf-init|tf-plan|tf-apply):' | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "\033[1;32mFor full infrastructure commands:\033[0m \033[33mcd iac && make help\033[0m"


# ====================================================================================
# BUILD & TEST
# ====================================================================================

.PHONY: build test release all update-deps

build: ## 🐳 Build the Docker image (debug/local build)
	@echo "\033[1;34m🐳 Building Docker image for $(PROJECT_NAME)...\033[0m"
	@docker build -t $(ECR_REPO_URI):latest .

test: ## 🧪 Run unit tests
	@echo "\033[1;34m🧪 Running unit tests...\033[0m"
	@.venv/bin/python -m pytest tests/ -v
	@echo "\033[1;32m✓ All tests passed!\033[0m"

release: ## 📦 Build a release-ready Docker image for a specific platform
	@echo "\033[1;34m📦 Building multi-platform Docker image for $(PROJECT_NAME) for platform $(DOCKER_PLATFORM)...\033[0m"
	@docker buildx build --platform $(DOCKER_PLATFORM) -t $(ECR_REPO_URI):latest .

all: test build ## ✨ Run tests and build the image

update-deps: ## 📦 Update all dependencies to their latest versions
	@echo "\033[1;34m📦 Updating Python dependencies...\033[0m"
	@uv pip compile pyproject.toml -o uv.lock
	@echo "\033[1;34m📦 Updating Terraform providers...\033[0m"
	@cd iac && terraform init -upgrade
	@echo "\033[1;32m✅ Dependencies updated!\033[0m"


# ====================================================================================
# DOCKER & ECR
# ====================================================================================

.PHONY: login push

login: ## 🔑 Authenticate Docker to AWS ECR
	@echo "\033[1;34m🔑 Authenticating Docker to ECR...\033[0m"
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

push: login release ## 🚀 Build, tag, and push the Docker image to ECR
	@echo "\033[1;34m🚀 Tagging and pushing Docker image to ECR...\033[0m"
	@docker push $(ECR_REPO_URI):latest


# ====================================================================================
# TERRAFORM & DEPLOYMENT
# ====================================================================================

.PHONY: deploy create-ecr oauth-config tf-init tf-plan tf-apply tf-destroy setup-backend

# Generic Terraform command proxy
tf-%: ## ⚙️ Terraform commands (e.g., make tf-plan, make tf-apply)
	@$(MAKE) -C iac tf-$* ARGS="$(ARGS)"

tf-apply: ## 🚀 Apply Terraform changes
	@$(MAKE) -C iac apply ARGS="$(ARGS)" TF_STATE_BUCKET=$(TF_STATE_BUCKET)

deploy: ## 🚀 Push Docker image and apply Terraform changes
	@$(MAKE) check-backend-config # Ensure backend is configured
	@$(MAKE) setup-backend TF_STATE_BUCKET=$(TF_STATE_BUCKET)
	@$(MAKE) create-ecr
	@sleep 10
	@echo "\033[1;32m✅ ECR repository $(ECR_REPO_NAME) is ready.\033[0m"
	@$(MAKE) push
	@$(MAKE) tf-apply
	@echo "\033[1;32mDeployment complete.\033[0m"

create-ecr: ## 📦 Create ECR repository via Terraform
	@$(MAKE) -C iac create-ecr

oauth-config: ## 📋 Display JWT configuration for A2A authentication
	@$(MAKE) -C iac oauth-config TF_STATE_BUCKET=$(TF_STATE_BUCKET)

setup-backend: ## ⚙️ Create S3/DynamoDB backend for Terraform state
	@echo "\033[1;34m⚙️  Setting up Terraform backend...\033[0m"
	@cd iac && $(MAKE) setup-backend


# ====================================================================================
# UTILITIES
# ====================================================================================

.PHONY: launch-a2a-inspector kill-a2a-inspector logs

launch-a2a-inspector: ## 🚀 Launch the A2A Inspector Docker container
	@echo "\033[1;34m🚀 Cloning and building a2aproject/a2a-inspector Docker image...\033[0m"
	@git clone https://github.com/a2aproject/a2a-inspector.git /tmp/a2a-inspector || true
	@cd /tmp/a2a-inspector && sed -i '' '/COPY pyproject.toml uv.lock .//i\RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*' Dockerfile # Install ca-certificates
	@cd /tmp/a2a-inspector && sed -i '' 's/uv sync/uv sync --native-tls/g' Dockerfile # Add --native-tls to uv sync
	@cd /tmp/a2a-inspector && docker build -t a2a-inspector .
	@echo "\033[1;34m🚀 Launching A2A Inspector on http://localhost:8080 in foreground for debugging. Press Ctrl+C to stop.\033[0m"
	@docker run --name a2a-inspector -p 8080:8080 a2a-inspector
	@echo "\033[1;32mA2A Inspector stopped.\033[0m"
	@echo "\033[1;33mTo clean up, run 'make kill-a2a-inspector'\033[0m"


kill-a2a-inspector: ## 🛑 Stop and remove the A2A Inspector Docker container
	@echo "\033[1;34m🛑 Stopping A2A Inspector Docker container...\033[0m"
	@docker stop a2a-inspector > /dev/null 2>&1 || true
	@docker rm a2a-inspector > /dev/null 2>&1 || true
	@echo "\033[1;32mA2A Inspector stopped and removed.\033[0m"

logs: ## 📜 Tail CloudWatch logs
	@echo "\033[1;34m📜 Tailing CloudWatch logs...\033[0m"
	@cd iac && $(MAKE) logs

# ====================================================================================
# CLEANUP
# ====================================================================================

.PHONY: clean

clean: ## 🧹 Clean up local build artifacts
	@echo "\033[1;34m🧹 Cleaning up local build artifacts...\033[0m"
	@rm -f iac/.terraform.lock.hcl
	@rm -rf iac/.terraform