variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "ap-southeast-2"
}

variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default = {
    Project     = "aws-agentcore-agent"
    ManagedBy   = "terraform"
    Environment = "production"
  }
}

variable "project_name" {
  description = "The name of the project (used as a base for resource names)."
  type        = string
  default     = "aws-agentcore-agent"
}

variable "agent_runtime_name_compliant" {
  description = "A compliant name for the Bedrock AgentCore Runtime (alphanumeric and underscores, starting with a letter, max 48 chars)."
  type        = string
  default     = "aws_agentcore_agent"
}

variable "ecr_force_delete" {
  description = "Whether to force delete the ECR repository."
  type        = bool
  default     = false
}

variable "terraform_locks_table_name" {
  description = "The name of the DynamoDB table for Terraform state locking."
  type        = string
  default     = "terraform-state-lock-agentcore"
}

variable "bedrock_agent_permissions_resources" {

  description = "List of resource ARNs for Bedrock actions. Use '*' for all resources (not recommended for production)."

  type = list(string)

  default = ["*"]

}



variable "gateway_exception_level" {

  description = "Exception level for Gateway error logging. Valid values are DEBUG, INFO, WARN, ERROR, or null for disabled."

  type = string

  default = null



  validation {

    condition = var.gateway_exception_level == null || contains(["DEBUG", "INFO", "WARN", "ERROR"], var.gateway_exception_level)

    error_message = "Exception level must be one of: DEBUG, INFO, WARN, ERROR, or null."

  }

}



# Entra ID OAuth Configuration

variable "entra_sign_in_audience" {

  description = "Entra ID sign-in audience"

  type = string

  default = "AzureADMultipleOrgs"

}



variable "entra_redirect_uris" {

  description = "List of redirect URIs for OAuth callbacks"

  type = list(string)

  default = [

    "http://localhost:6274/callback/"

  ]

}



variable "preserve_existing_redirect_uris" {

  description = "List of existing redirect URIs to preserve (e.g., existing application connector URIs)"

  type = list(string)

  default = []

}



variable "entra_group_membership_claims" {

  description = "Group membership claims to include in tokens"

  type = list(string)

  default = ["SecurityGroup"]

}



variable "entra_oauth_scope_value" {

  description = "OAuth scope value (used in token requests)"

  type = string

  default = "access_as_user"

}

variable "terraform_state_bucket_name" {
  description = "The name of the S3 bucket to store the Terraform state."
  type        = string
}