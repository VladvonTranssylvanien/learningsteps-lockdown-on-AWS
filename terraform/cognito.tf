resource "aws_cognito_user_pool" "main" {
  name                     = "userpool-${var.prefix}"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  deletion_protection      = "ACTIVE"

  password_policy {
    minimum_length    = 14
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  # Enforced MFA for stronger account security.
  mfa_configuration = "ON"

  software_token_mfa_configuration {
    enabled = true
  }

  tags = local.common_tags
}

# The "Domain" is Cognito's hosted login page URL prefix
# (becomes https://<domain>.auth.<region>.amazoncognito.com)
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.prefix}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_user_pool_client" "oauth2_proxy" {
  name         = "oauth2-proxy-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = true

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  supported_identity_providers = ["COGNITO"]

  callback_urls = ["https://${var.prefix_domain}/oauth2/callback"]
  logout_urls   = ["https://${var.prefix_domain}/"]

  explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}
