
output "virtual_network_id" {
  value = module.vnet.vnet_id
}

output "subnet_ids" {
  description = "Map of subnet IDs"
  value       = module.vnet.subnet_ids
}

# Public IP


output "public_ip_addresses" {
  value = { for k, m in module.public_ip : k => m.public_ip_addresses }
}


# VM




output "vm_name" {
  description = "Virtual Machine name"
  value       = {for name , vm in module.vm : name => vm.vm_name}
}



output "private_ip_address" {
  description = "private IP address of the VM"
  value       = { for key , vm in module.vm    : key  =>vm.private_ip_address}
}





