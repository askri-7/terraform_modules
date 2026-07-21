resource "azurerm_public_ip" "pub_ip" {
  for_each            = var.pub_ips  
  name                = each.key
  location            = each.value.public_ip_location
  resource_group_name = var.resource_group_name
  allocation_method   = each.value.allocation
  sku                 = each.value.sku
}
