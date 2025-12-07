# Configure AWS Providers
provider "aws" {
  region = var.aws_region
}

# --- Cognito User Pool ---
resource "aws_cognito_user_pool" "main" {
  name = "${var.prefix}-${var.project_name}-user-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  auto_verified_attributes = ["email"]
  mfa_configuration = "ON"
  
  software_token_mfa_configuration {
      enabled = true
  }

  admin_create_user_config {
    # Set to true to disable self-registration and only allow administrators to create users.
    allow_admin_create_user_only = true
  }
  tags = {
    Name        = "${var.prefix}-${var.project_name}-user-pool"
    Environment = "Development"
  }
}

# --- Cognito User Pool Domain (AWS-managed with custom prefix) ---
# This configures the domain like: https://your-chosen-prefix.auth.<region>.amazoncognito.com
resource "aws_cognito_user_pool_domain" "main_aws_managed_prefix" {
  user_pool_id = aws_cognito_user_pool.main.id
  domain       = "${var.prefix}-${var.project_name}-auth" # Use the variable for your chosen prefix
  managed_login_version = 2
}
# --- Cognito User Pool UI Customization ---
resource "aws_cognito_user_pool_ui_customization" "custom_style" {
  user_pool_id = aws_cognito_user_pool.main.id
  client_id    = aws_cognito_user_pool_client.web_app_client.id 
}

# --- Cognito User Pool Client (Configured for SPA with PKCE) ---
resource "aws_cognito_user_pool_client" "web_app_client" {
  name                                 = "${var.prefix}-${var.project_name}-web-app-client"
  user_pool_id                         = aws_cognito_user_pool.main.id
  generate_secret                      = false # Set to 'false' for SPAs using PKCE!
  explicit_auth_flows                  = ["ALLOW_ADMIN_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors        = "ENABLED"

  callback_urls = var.cloudfront_app_callback_urls
  logout_urls   = var.cloudfront_app_logout_urls

  allowed_oauth_scopes          = ["openid", "email", "profile", "phone"]
  allowed_oauth_flows           = ["code"] # Only 'code' flow for SPAs with PKCE
  allowed_oauth_flows_user_pool_client = true # Required when using allowed_oauth_flows

  supported_identity_providers = ["COGNITO"]
}


# --- Outputs ---
output "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool."
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_client_id" {
  description = "The ID of the Cognito User Pool Client."
  value       = aws_cognito_user_pool_client.web_app_client.id
}

# This is the desired output for the AWS-managed Cognito domain
output "cognito_hosted_ui_domain" {
  description = "The AWS-managed domain for the Cognito Hosted UI (e.g., https://your-prefix.auth.us-east-1.amazoncognito.com)."
  value       = "https://${aws_cognito_user_pool_domain.main_aws_managed_prefix.domain}.auth.${var.aws_region}.amazoncognito.com"
}

