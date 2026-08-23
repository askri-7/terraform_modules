output "key_vault_name" {
  value = azurerm_key_vault.app.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.app.vault_uri
}