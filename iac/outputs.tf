output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository."
  value       = aws_ecr_repository.agentcore_repo.repository_url
}

output "agentcore_runtime_id" {
  description = "The ID of the Bedrock Agentcore Runtime."
  value       = awscc_bedrockagentcore_runtime.agentcore_runtime.id
}

output "entra_app_client_id" {
  description = "The Client ID of the Entra ID Application Registration."
  value       = azuread_application.agentcore_app.client_id
}

output "entra_tenant_id" {
  description = "The Tenant ID of the Azure AD tenant."
  value       = data.azuread_client_config.current.tenant_id
}

output "entra_client_secret" {
  description = "The client secret for external agent connectors."
  value       = azuread_application_password.external_connector.value
  sensitive   = true
}