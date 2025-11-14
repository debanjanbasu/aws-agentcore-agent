# AWS Bedrock Agentcore Agent with Strands

This project demonstrates how to deploy a Python-based agent using the `strands` SDK to Amazon Bedrock Agentcore Runtime. The agent is exposed as a FastAPI application within a Docker container, allowing it to be hosted on the Agentcore Runtime for scalable and efficient execution.

## Architecture

```
User Input
      ↓
Amazon Bedrock Agentcore Runtime (Container)
      ↓
FastAPI Application (agent.py)
      ↓
Strands Agent (with tools like calculator, current_time, letter_counter)
      ↓
Amazon Bedrock Models / External APIs (via tools)
      ↓
Agent Response
      ↓
User Output
```

## Features

*   **Strands SDK Integration**: Leverage the `strands` framework for building robust and extensible agents.
*   **FastAPI Backend**: A lightweight and high-performance web framework for the agent's API.
*   **Amazon Bedrock Agentcore Runtime**: Deploy the agent as a containerized application on AWS's dedicated runtime for Bedrock agents.
*   **Containerized Deployment**: Docker-based deployment for consistency and portability.
*   **Terraform for Infrastructure**: Manage AWS resources (ECR, IAM, Agentcore Runtime) using Infrastructure as Code.
*   **Optimized Docker Image**: Uses Debian-based Python images with `uv` for efficient dependency management, ensuring compatibility with compiled packages like `asyncpg` while targeting ARM64 for Graviton instances.
*   **Automated Workflow**: This project utilizes two `Makefile`s to streamline build, deploy, and cleanup processes: a root `Makefile` for application-level tasks and a dedicated `iac/Makefile` for infrastructure-specific operations. This separation clearly delineates application and infrastructure concerns.

## Prerequisites

Before you begin, ensure you have the following installed and configured:

*   **AWS CLI**: Configured with credentials to deploy resources in your AWS account.
*   **Docker** (or Finch/Podman): For building and managing Docker images.
*   **Terraform**: For deploying and managing AWS infrastructure.
*   **Python 3.11+**: For local development and testing of the `strands` agent.
*   **uv**: A fast Python package installer and resolver (`pip install uv`).

## Structure

```
.
├── .gitignore
├── .python-version
├── agent.py              # The Strands agent implemented as a FastAPI application
├── Dockerfile            # Defines the Docker image for the agent
├── Makefile              # Automation for build, deploy, and cleanup tasks (application-level)
├── pyproject.toml        # Project dependencies and metadata
├── README.md             # This file
├── uv.lock               # Locked dependencies for uv
└── iac/                  # Infrastructure as Code (Terraform)
    ├── Makefile          # Automation for Terraform-specific tasks
    ├── agentcore_runtime.tf # Defines ECR, IAM Role, and Bedrock Agentcore Runtime
    ├── outputs.tf        # Terraform outputs
    ├── provider.tf       # AWS and AWSCC provider configuration
    └── variables.tf      # Terraform input variables
```

## Quick Start

Follow these steps to get your agent deployed and running:

1.  **Configure AWS CLI**: Ensure your AWS CLI is configured with appropriate permissions.
2.  **Setup Terraform Backend**:
    ```bash
    make setup-backend
    ```
    This command will prompt you for a globally unique S3 bucket name and set up an S3 bucket for Terraform state and a DynamoDB table for state locking.
3.  **Deploy**:
    ```bash
    make deploy
    ```
    This command will:
    *   Build the Docker image for `linux/arm64`.
    *   Authenticate Docker to ECR.
    *   Create the ECR repository and its policy if they don't exist.
    *   Tag and push the Docker image to your ECR repository.
    *   Initialize and apply the Terraform configuration to deploy the Agentcore Runtime.

## Deployment Steps (Detailed)

The `make deploy` command in the root `Makefile` orchestrates the entire deployment process. However, you can also run individual steps:

### 1. Build and Push Docker Image

```bash
# Build the Docker image (for linux/arm64 by default)
make release

# Authenticate Docker to ECR, create ECR repo and its policy if needed, tag and push the Docker image
make push
```

### 2. Deploy Terraform Infrastructure

First, set up the Terraform backend:
```bash
make setup-backend
```

Then, initialize Terraform and apply the infrastructure:
```bash
make tf-init
make tf-apply
```

## Configuration

You can customize the deployment by modifying the variables in `iac/variables.tf` or by creating a `iac/terraform.tfvars` file.

*   **`ecr_repo_name`**: The name of the ECR repository. Defaults to `aws-agentcore-agent-repo`.
*   **`bedrock_agent_permissions_resources`**: By default, the agent's IAM role has `*` permissions for Bedrock actions. In a production environment, you should restrict this to specific model ARNs. You can set this variable in `iac/terraform.tfvars` to a list of specific ARNs.
*   **Terraform Backend**: The `terraform_state_bucket_name` and `terraform_locks_table_name` are configured when you run `make setup-backend`. You can also manually edit the `iac/backend.config` file after it's generated.

### Azure AD (Entra ID) Configuration

This project integrates with Azure AD for JWT authentication of the Bedrock Agentcore Runtime, enabling secure agent-to-agent (A2A) communication. To configure Azure AD, you will need to:

1.  **Authenticate Azure CLI**: Ensure your Azure CLI is authenticated to the correct tenant.
2.  **Deploy Azure AD Resources**: Run `make deploy` (or `make tf-apply`) to provision the Azure AD application and related resources defined in `iac/entra_oauth.tf`.
3.  **Get JWT Configuration**: Use `make oauth-config` to display the necessary details for configuring external agents for JWT authentication.

    **Note**: For testing A2A communication, you might find the `a2aproject/a2a-inspector` tool useful. It can be configured with the JWT details obtained from `make oauth-config` to simulate agent-to-agent calls.

### A2A Inspector

The A2A Inspector is a tool that helps you visualize and debug agent-to-agent communication.

*   **Launch Inspector**:
    ```bash
    make launch-a2a-inspector
    ```
    This will pull the `a2aproject/a2a-inspector` Docker image and run it, exposing the inspector UI on `http://localhost:8080`.
*   **Stop Inspector**:
    ```bash
    make kill-a2a-inspector
    ```
    This will stop and remove the A2A Inspector Docker container.

Example `iac/terraform.tfvars`:

```hcl
project_name          = "agentcore-project"
aws_region          = "ap-southeast-2" # Default region
common_tags = {
  Environment = "Production"
  Owner       = "MyTeam"
}
bedrock_agent_permissions_resources = [
  "arn:aws:bedrock:ap-southeast-2::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
  "arn:aws:bedrock:ap-southeast-2::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
]
```

## Testing

This project includes basic testing for the Terraform configuration:

*   **Terraform Validation**: The `make test` command (or `cd iac && make test`) runs `terraform validate` and `terraform plan` to ensure the infrastructure code is syntactically correct and can generate an execution plan without errors.

To run the Terraform tests:
```bash
make test
```

For agent-specific unit and integration tests, you would add them to your Python project and integrate them into the `make test` command in the root `Makefile` (currently a placeholder).

## Troubleshooting

*   **ECR Repository Not Found**: If you encounter errors related to the ECR repository not existing, ensure you have run `make create-ecr` (or `make deploy` which includes it) to provision the ECR repository, its policy, and other core infrastructure before pushing the Docker image. The `make create-ecr` command now performs a full `terraform apply` to ensure all necessary resources are provisioned.
*   **ECR Login Issues**: Ensure your AWS CLI credentials are valid and you have `ecr:GetAuthorizationToken` permissions.
*   **Terraform Apply Failures**: Check the Terraform output for specific error messages. Ensure your IAM user/role has permissions to create ECR repositories, IAM roles, and Bedrock Agentcore Runtimes. Use `make tf-plan` to preview changes before applying.
*   **Agentcore Runtime Errors**: Check CloudWatch logs for the Agentcore Runtime for detailed error messages from your FastAPI application. You can use `make logs` to tail these.
*   **Image Pull Errors**: Verify that the ECR repository URL in `iac/agentcore_runtime.tf` matches your pushed image and that the Agentcore Runtime's IAM role has `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`, `ecr:BatchCheckLayerAvailability` permissions for your repository.

## Cleanup

To remove all deployed AWS resources:

```bash
make tf-destroy
```

## Commands

| Command | Description |
|---|---|
| **Development Commands** | |
| `make build` | Builds the Docker image locally (single platform, for quick local testing) |
| `make python-test` | Runs Python tests (placeholder) |
| | |
| **Deployment Commands** | |
| `make login` | Authenticates Docker to ECR |
| `make release` | Builds the Docker image for the specified `DOCKER_PLATFORM` (default: `linux/arm64`) |
| `make push` | Builds (release), logs in, tags, and pushes the Docker image to ECR |
| `make setup-backend` | Creates S3/DynamoDB backend for Terraform state |
| `make create-ecr` | Creates ECR repository and its policy if they don't exist (calls `iac/Makefile` and performs a full `terraform apply`) |
| `make deploy` | Pushes Docker image and deploys Terraform (calls `iac/Makefile` for `tf-apply`) |
| `make oauth-config` | Displays JWT configuration for A2A authentication (calls `iac/Makefile`) |
| `make launch-a2a-inspector` | Launches the A2A Inspector Docker container |
| `make kill-a2a-inspector` | Stops and removes the A2A Inspector Docker container |
| | |
| **Maintenance Commands** | |
| `make clean` | Cleans up local build artifacts and Terraform backend config |
| `make logs` | Tails CloudWatch logs (placeholder) |
| `make test` | Validates and plans Terraform configuration (calls `iac/Makefile`) |
| `make tf-destroy` | Destroys Terraform infrastructure (calls `iac/Makefile`) |
| | |
| `make help` | Show this help message (and `cd iac && make help` for iac commands) |