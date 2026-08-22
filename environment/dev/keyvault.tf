data "azurerm_client_config" "current" {}

# ── Key Vault ──
resource "azurerm_key_vault" "app" {
  name                = "${var.naming.project}-${var.naming.environment}-kv"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  purge_protection_enabled   = false
  soft_delete_retention_days = 7
}

# ── Key Vault Access Policy: VM reads secrets ──
resource "azurerm_key_vault_access_policy" "vm" {
  key_vault_id = azurerm_key_vault.app.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.vm.principal_id

  secret_permissions = ["Get", "List"]

  lifecycle {
    create_before_destroy = true
  }
}

# ── Key Vault Access Policy: Terraform runner (GitHub Actions) creates secrets ──
resource "azurerm_key_vault_access_policy" "terraform_runner" {
  key_vault_id = azurerm_key_vault.app.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.github_actions_identity.principal_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]

  lifecycle {
    create_before_destroy = true
  }
}

# ── Store Secrets ──
resource "azurerm_key_vault_secret" "database_url" {
  name         = "database-url"
  value        = local.database_url
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [azurerm_key_vault_access_policy.vm, azurerm_key_vault_access_policy.terraform_runner]
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = var.jwt_secret
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [azurerm_key_vault_access_policy.vm, azurerm_key_vault_access_policy.terraform_runner]
}

resource "azurerm_key_vault_secret" "github_client_secret" {
  name         = "github-client-secret"
  value        = var.github_client_secret
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [azurerm_key_vault_access_policy.vm, azurerm_key_vault_access_policy.terraform_runner]
}

resource "azurerm_key_vault_secret" "google_client_secret" {
  name         = "google-client-secret"
  value        = var.google_client_secret
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [azurerm_key_vault_access_policy.vm, azurerm_key_vault_access_policy.terraform_runner]
}

resource "azurerm_key_vault_secret" "smtp_pass" {
  name         = "smtp-pass"
  value        = var.smtp_pass
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [azurerm_key_vault_access_policy.vm, azurerm_key_vault_access_policy.terraform_runner]
}
