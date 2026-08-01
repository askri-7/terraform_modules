# make a vnet with ddos var plan
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.virtual_network_location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space # private ip adress range

  # configure ddos protection
    dynamic "ddos_protection_plan" {
        for_each = var.ddos_protection_plan != null ? [var.ddos_protection_plan] : []
        content {
          enable = ddos_protection_plan.value.enable
          id     = ddos_protection_plan.value.id
        }
    }

  tags = var.tags
}
#subnet
resource "azurerm_subnet" "dynamic" {
  for_each = var.dynamic_subnets # itteration

  name                 = "${var.vnet_name}-${each.key}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value.cidr_block]
 
  dynamic "delegation" {

    for_each = each.value.delegation != null ? [each.value.delegation] : []


    content {

      name = delegation.value.name


      service_delegation {

        name = delegation.value.service_name

        actions = delegation.value.actions

      }
    }
  }

}

#nsg
resource "azurerm_network_security_group" "dynamic" {
  for_each = var.dynamic_subnets

  name                = "${var.vnet_name}-${each.key}-nsg"
  location            = azurerm_virtual_network.vnet.location
  resource_group_name = var.resource_group_name
  #skip CKV_AZURE_160 allow http on 80 to redirect later
  dynamic "security_rule" { # security_rule is the itterator
    for_each = each.value.security_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "association" {
  for_each                  = var.dynamic_subnets
  subnet_id                 = azurerm_subnet.dynamic[each.key].id
  network_security_group_id = azurerm_network_security_group.dynamic[each.key].id

}
