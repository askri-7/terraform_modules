terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

module "rg_00" {
  source   = "./modules/resource-group"
  name     = "internship-web-${module.naming.resource_group.name_unique}-00"
  location = var.resource_group_location
}

module "rg_01" {
  source   = "./modules/resource-group"
  name     = "internship-web-${module.naming.resource_group.name_unique}-01"
  location = var.resource_group_location
}

module "rg_02" {
  source   = "./modules/resource-group"
  name     = coalesce(
    "internship-web-${module.naming.resource_group.name_unique}-02",
    var.resource_group_name,
  )
  location = var.resource_group_location
}