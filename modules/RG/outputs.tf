output "name" {
  value = azurerm_resource_group.rg.name
  description = "rg name"
}
output "location" {
    value =azurerm_resource_group.rg.location
    description = "rg location"
}

output "id" {
  value = azurerm_resource_group.rg.id
  description = "rg id"
}