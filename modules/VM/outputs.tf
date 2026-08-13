output "vm_id" {
  description = "The ID of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_name" {
  description = "The name of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "nic_id" {
  description = "The ID of the network interface"
  value       = azurerm_network_interface.nic.id
}

output "private_ip_address" {
  description = "The private IP address of the VM"
  value       = azurerm_network_interface.nic.private_ip_address
}

#the first IP configuration
output "public_ip_id" {
  description = "The ID of the public IP attached to the NIC"
  value       = azurerm_network_interface.nic.ip_configuration[0].public_ip_address_id
}

output "location" {
  description = "The Azure region of the VM + NIC"
  value       = azurerm_linux_virtual_machine.vm.location
}

output "principal_id" {
  description = "System-assigned managed identity principal ID"
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}