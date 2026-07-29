resource "azurerm_public_ip" "pub_ip" {
  
  name                = var.pip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = var.pip_allocation
  sku                 = var.pip_sku
  tags                = var.tags
}
