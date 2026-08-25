
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "app" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  
  enable_rbac_authorization   = true
  enabled_for_disk_encryption = true
  sku_name                    = "standard"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  #soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  tags = var.tags

}
resource "azurerm_role_assignment" "vm_kv_reader" {
    scope = azurerm_key_vault.app.id
    role_definition_name = "key Vault Secrets User" # readonly
    principal_id = var.vm_principal_id
}

resource "azurerm_role_assignment" "ci_kv_officer" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets Officer" # read/write
  principal_id         = var.workflow_identity_principal_id
}
  
resource "azurerm_role_assignment" "local_admin_kv_officer" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.terraform_admin_object_id
}

resource "time_sleep" "wait_for_kv_rbac" {
  depends_on = [
    azurerm_role_assignment.ci_kv_officer,
    azurerm_role_assignment.local_admin_kv_officer,
  ]
  create_duration = "30s"
}




resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = var.jwt_secret
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [time_sleep.wait_for_kv_rbac]

}

resource "azurerm_key_vault_secret" "github_client_secret" {
  name         = "github-client-secret"
  value        = var.github_client_secret
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [time_sleep.wait_for_kv_rbac]

}

resource "azurerm_key_vault_secret" "google_client_secret" {
  name         = "google-client-secret"
  value        = var.google_client_secret
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [time_sleep.wait_for_kv_rbac]

}


resource "azurerm_key_vault_secret" "smtp_pass" {
  name         = "smtp-pass"
  value        = var.smtp_pass
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [time_sleep.wait_for_kv_rbac]

}

resource "azurerm_key_vault_secret" "admin_password" {
  name         = "admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [time_sleep.wait_for_kv_rbac]

}

resource "azurerm_key_vault_secret" "admin_email" {
  name         = "admin-email"
  value        = var.admin_email
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [time_sleep.wait_for_kv_rbac]

}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [time_sleep.wait_for_kv_rbac]

}

