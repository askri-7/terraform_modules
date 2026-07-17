resource "azurerm_virtual_network" "vnet"{
    name     = var.virtual_network_name
    location = var.virtual_network_location
    resource_group_name = var.resource_group_name
    address_space = var.address_space

    dynamic "ddos_protection_plan" {
        for_each = var.ddos_protection_plan != null ? [var.ddos_protection_plan] : []
        content {
          enable = ddos_protection_plan.value.enable
          id     = ddos_protection_plan.value.id
        }
    }

}
#subnet
resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = var.address_prefixes
}
#nsg
resource "azurerm_network_security_group" "example" {
  name                = var.nsg_name
  location            = var.virtual_network_location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = var.security_rules
    priority                   = var.sr_priority
    direction                  = var.sr_direction
    access                     = var.sr_access
    protocol                   = var.sr_protocol
    source_port_range          = var.sr_source_port_range
    destination_port_range     = var.sr_destination_port_range
    source_address_prefix      = var.source_address_prefix
    destination_address_prefix = var.destination_address_prefix
  }
}