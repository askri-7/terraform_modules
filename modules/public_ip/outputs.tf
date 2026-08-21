output "public_ip_addresses" {
  description = "map of public IP addresses"
  value       = azurerm_public_ip.pub_ip.ip_address
}

output "id" {
  description = "resource ID of the public IP"
  value       = azurerm_public_ip.pub_ip.id
}