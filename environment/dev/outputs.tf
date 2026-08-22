
output "virtual_network_id" {
  value = module.vnet.vnet_id
}

output "subnet_ids" {
  description = "Map of subnet IDs"
  value       = module.vnet.subnet_ids
}

# Public IP


output "public_ip_addresses" {
  description = "Map of Public IP addresses"
  value       = module.public_ip.public_ip_addresses
}


# VM

output "github_client_id" {
  value = module.github_actions_identity.client_id
}


output "vm_name" {
  description = "Virtual Machine name"
  value       = module.vm.vm_name
}



output "private_ip_address" {
  description = "private IP address of the VM"
  value       = module.vm.private_ip_address
}





