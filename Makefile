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
	@echo "Building Docker image for $(PROJECT_NAME)..."
	@docker build -t $(ECR_REPO_URI):latest .

test: ## 🧪 Run unit tests
	@echo "Running unit tests..."
	@.venv/bin/python -m pytest tests/ -v
	@echo "✓ All tests passed!"

release: ## 📦 Build a release-ready Docker image for a specific platform
	@echo "Building multi-platform Docker image for $(PROJECT_NAME) for platform $(DOCKER_PLATFORM)..."
	@docker buildx build --platform $(DOCKER_PLATFORM) -t $(ECR_REPO_URI):latest .

all: test build ## ✨ Run tests and build the image

update-deps: ## 📦 Update all dependencies to their latest versions
	@echo "Updating Python dependencies..."
	@uv pip compile pyproject.toml -o uv.lock
	@echo "Updating Terraform providers..."
	@cd iac && terraform init -upgrade
	@echo "✅ Dependencies updated!"


# ====================================================================================
# DOCKER & ECR
# ====================================================================================

.PHONY: login push

login: ## 🔑 Authenticate Docker to AWS ECR
	@echo "Authenticating Docker to ECR..."
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

push: login release ## 🚀 Build, tag, and push the Docker image to ECR
	@echo "Tagging and pushing Docker image to ECR..."
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
	@$(MAKE) setup-backend TF_STATE_BUCKET=$(TF_STATE_BUCKET)
	@$(MAKE) create-ecr
	@sleep 10
	@echo "✅ ECR repository $(ECR_REPO_NAME) is ready."
	@$(MAKE) push
	@$(MAKE) tf-apply
	@echo "Deployment complete."

create-ecr: ## 📦 Create ECR repository via Terraform
	@$(MAKE) -C iac create-ecr

oauth-config: ## 📋 Display JWT configuration for A2A authentication
	@$(MAKE) -C iac oauth-config TF_STATE_BUCKET=$(TF_STATE_BUCKET)

setup-backend: ## ⚙️ Create S3/DynamoDB backend for Terraform state
	@echo "Setting up Terraform backend..."
	@cd iac && $(MAKE) setup-backend


# ====================================================================================
# UTILITIES
# ====================================================================================

.PHONY: launch-a2a-inspector kill-a2a-inspector logs

launch-a2a-inspector: ## 🚀 Launch the A2A Inspector Docker container
	@echo "Cloning and building a2aproject/a2a-inspector Docker image..."
	@git clone https://github.com/a2aproject/a2a-inspector.git /tmp/a2a-inspector || true
	@cd /tmp/a2a-inspector && docker build -t a2a-inspector .
	@echo "Launching A2A Inspector on http://localhost:8080"
	@docker run -d --rm --name a2a-inspector -p 8080:8080 a2a-inspector
	@echo "A2A Inspector launched. Access it at http://localhost:8080"
	@echo "To stop it, run 'make kill-a2a-inspector'"

kill-a2a-inspector: ## 🛑 Stop and remove the A2A Inspector Docker container
	@echo "Stopping A2A Inspector Docker container..."
	@docker stop a2a-inspector > /dev/null 2>&1 || true
	@docker rm a2a-inspector > /dev/null 2>&1 || true
	@echo "A2A Inspector stopped and removed."

logs: ## 📜 Tail CloudWatch logs
	@echo "Tailing CloudWatch logs..."
	@cd iac && $(MAKE) logs

# ====================================================================================
# CLEANUP
# ====================================================================================

.PHONY: clean

clean: ## 🧹 Clean up local build artifacts
	@echo "Cleaning up local build artifacts..."
	@rm -f iac/.terraform.lock.hcl
	@rm -rf iac/.terraform