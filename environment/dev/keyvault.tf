

# ── Data source for current Azure tenant ──
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
# The VM's system-assigned identity principal_id comes from the module output
resource "azurerm_key_vault_access_policy" "vm" {
  key_vault_id = azurerm_key_vault.app.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.vm.principal_id

  secret_permissions = ["Get", "List"]
}

# ── Store Secrets ──
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [azurerm_key_vault_access_policy.vm]
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = var.jwt_secret
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [azurerm_key_vault_access_policy.vm]
}

resource "azurerm_key_vault_secret" "admin_password" {
  name         = "admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [azurerm_key_vault_access_policy.vm]
}

resource "azurerm_key_vault_secret" "github_client_secret" {
  name         = "github-client-secret"
  value        = var.github_client_secret
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [azurerm_key_vault_access_policy.vm]
}

resource "azurerm_key_vault_secret" "google_client_secret" {
  name         = "google-client-secret"
  value        = var.google_client_secret
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [azurerm_key_vault_access_policy.vm]
}

resource "azurerm_key_vault_secret" "admin_email" {
  name         = "admin-email"
  value        = var.admin_email
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [azurerm_key_vault_access_policy.vm]
}

resource "azurerm_key_vault_secret" "db_user" {
  name         = "db_user"
  value        = var.db_user
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [azurerm_key_vault_access_policy.vm]
}

