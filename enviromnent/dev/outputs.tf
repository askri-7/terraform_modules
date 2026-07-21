
output "virtual_network_id" {
  value = module.vnet.vnet_id
}

output "subnet_ids" {
  description = "Map of subnet IDs"
  value       = module.vnet.subnet_ids
}

# Public IPs
output "public_ip_ids" {
  description = "Map of Public IP IDs"
  value       = module.public_ip.public_ip_ids
}

output "public_ip_addresses" {
  description = "Map of Public IP addresses"
  value       = module.public_ip.public_ip_addresses
}


# VM


output "vm_id" {
  description = "Virtual Machine ID"
  value       = module.vm.vm_id
}

output "vm_name" {
  description = "Virtual Machine name"
  value       = module.vm.vm_name
}

output "network_interface_id" {
  description = "Network Interface ID"
  value       = module.vm.nic_id
}

output "private_ip_address" {
  description = "Private IP address of the VM"
  value       = module.vm.private_ip_address
}


# Helper output



