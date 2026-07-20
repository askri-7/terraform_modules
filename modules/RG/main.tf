module "naming" {
   source  = "Azure/naming/azurerm"
   version = "0.4.3"
}

resource "azurerm_resource_group" "rg" {
  name = "${var.resource_group_name}-${module.naming.resource_group.name_unique}"
  location = var.resource_group_location

}