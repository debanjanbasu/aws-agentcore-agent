# ECR Repository for the Agentcore Docker Image
resource "aws_ecr_repository" "agentcore_repo" {
  name                 = "${var.project_name}-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }
}

# IAM Role for Bedrock Agentcore Runtime
resource "aws_iam_role" "agentcore_runtime_role" {
  name = "${var.project_name}-runtime-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "bedrock-agentcore.amazonaws.com"
        }
      },
    ],
  })

  tags = var.common_tags
}


# ECR Repository Policy to allow Bedrock Agentcore service to pull images
resource "aws_ecr_repository_policy" "agentcore_repo_policy" {
  repository = aws_ecr_repository.agentcore_repo.name

  policy = jsonencode({
    Version = "2008-10-17",
    Statement = [
      {
        Sid    = "AllowBedrockAgentcorePull",
        Effect = "Allow",
        Principal = {
          Service = "bedrock-agentcore.amazonaws.com"
        },
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetLifecyclePolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:GetRepositoryPolicy"
        ]
      }
    ]
  })
}



# IAM Policy for Bedrock Agentcore Runtime
data "aws_iam_policy_document" "agentcore_runtime_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetAuthorizationToken",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "agentcore_runtime_policy" {
  name   = "${var.project_name}-runtime-policy"
  policy = data.aws_iam_policy_document.agentcore_runtime_policy.json
}

resource "aws_iam_role_policy_attachment" "agentcore_runtime_policy_attachment" {
  role       = aws_iam_role.agentcore_runtime_role.name
  policy_arn = aws_iam_policy.agentcore_runtime_policy.arn
}

# Data source for AWS Caller Identity to get account ID
data "aws_caller_identity" "current" {}

resource "aws_bedrockagentcore_agent_runtime" "agentcore_runtime" {
  agent_runtime_name = var.agent_runtime_name_compliant
  role_arn           = aws_iam_role.agentcore_runtime_role.arn
  tags               = var.common_tags

  agent_runtime_artifact {
    container_configuration {
      container_uri = "${aws_ecr_repository.agentcore_repo.repository_url}:latest"
    }
  }

  network_configuration {
    network_mode = "PUBLIC"
  }

  authorizer_configuration {
    custom_jwt_authorizer {
      discovery_url = local.entra_discovery_url
      allowed_audience = [
        azuread_application.agentcore_app.client_id
      ]
      allowed_clients = [
        azuread_application.agentcore_app.client_id
      ]
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.agentcore_runtime_policy_attachment,
    aws_ecr_repository_policy.agentcore_repo_policy
  ]
}

resource "aws_bedrockagentcore_agent_runtime_endpoint" "agentcore_runtime_endpoint" {
  name             = "${var.agent_runtime_name_compliant}-endpoint"
  agent_runtime_id = aws_bedrockagentcore_agent_runtime.agentcore_runtime.id
  description      = "Endpoint for agent runtime communication for ${var.agent_runtime_name_compliant}"
  tags             = var.common_tags
}