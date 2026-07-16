data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

/*
module "VM" {
    source  = "../../modules/VM"
  
}
module "Vnet" {
    source  = "../../modules/Vnet"

}
*/