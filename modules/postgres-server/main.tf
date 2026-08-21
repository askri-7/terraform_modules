resource "azurerm_private_dns_zone" "private" {
  name                =var.private_dns
  resource_group_name = var.resource_group_name
}

# link the dns with the network id then it allows private dns resolve
resource "azurerm_private_dns_zone_virtual_network_link" "link" {
  name                  = "${var.postgresql_name}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.private.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
}

resource "azurerm_postgresql_flexible_server" "example" {
  name                          = var.postgresql_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = var.postgresql_metadata.version
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = azurerm_private_dns_zone.private.id
  public_network_access_enabled = false
  administrator_login           = var.postgresql_administrator_login
  administrator_password        = var.postgresql_administrator_password
  zone                          = var.postgresql_metadata.zone

  storage_mb   = var.postgresql_metadata.storage_mb
  storage_tier = var.postgresql_metadata.storage_tier

  sku_name   = var.postgresql_metadata.sku_name
  depends_on = [azurerm_private_dns_zone_virtual_network_link.link]

}