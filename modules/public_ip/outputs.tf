output "public_ip_ids" {
  value = {
    for name, public_ip in azurerm_public_ip.pub_ip :
    name => public_ip.id
  }
}

output "public_ip_addresses" {
  description = "map of public IP addresses"

  value = {
    for name, ip in azurerm_public_ip.pub_ip :
    name => ip.ip_address
  }
}