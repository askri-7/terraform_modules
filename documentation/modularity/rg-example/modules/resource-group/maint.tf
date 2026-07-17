resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location

  lifecycle {
    create_before_destroy = true
  }
}