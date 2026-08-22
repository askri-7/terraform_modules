output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}


output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}


output "subnet_ids" {
  value = {
    for subnet_name, subnet in azurerm_subnet.dynamic : # iterate with key value 
    subnet_name => subnet.id
  }
}


output "nsg_ids" {
  value = {
    for nsg_name, nsg in azurerm_network_security_group.dynamic :
    nsg_name => nsg.id
  }
}