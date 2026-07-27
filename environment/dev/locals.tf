locals {
  default_audience_name = "api://AzureADTokenExchange"
  github_issuer_url     = "https://token.actions.githubusercontent.com"
}

locals {
  vm_roles = {
    frontend = { subnet_key = "frontend", has_public_ip = true }
    backend  = { subnet_key = "backend",  has_public_ip = false }
    redis    = { subnet_key = "redis",    has_public_ip = false }
    database = { subnet_key = "database", has_public_ip = false }
  }
}