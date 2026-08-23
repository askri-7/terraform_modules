locals {
  default_audience_name = "api://AzureADTokenExchange"
  github_issuer_url     = "https://token.actions.githubusercontent.com"

  # Derived from domain_name — single source of truth
  frontend_url        = "https://${var.domain_name}"
  api_url             = "https://${var.domain_name}/api"
  github_callback_url = "https://${var.domain_name}/api/auth/github/callback"
  google_callback_url = "https://${var.domain_name}/api/auth/google/callback"
  database_url        = "postgresql://${var.db_user}:${var.db_password}@db:5432/${var.db_name}"
}
