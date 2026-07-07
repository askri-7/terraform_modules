# Configure the Azure provider
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

module "naming00" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
  
}
module "naming_00" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

module "naming_01" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}
locals {
  resource_group_name = coalesce("internship-web-${module.naming00.resource_group.name_unique}-02", var.resource_group_name, )
}
resource "azurerm_resource_group" "internship-web-rg-00" {
  name     = "internship-web-${module.naming_00.resource_group.name_unique}-00"
  location = var.resource_group_location
  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_resource_group" "internship-web-rg-01" {
  name     = "internship-web-${module.naming_01.resource_group.name_unique}-01"
  location = var.resource_group_location
  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_resource_group" "internship-web-rg-000" {
  name     = local.resource_group_name
  location = var.resource_group_location
  lifecycle {
    create_before_destroy = true
  }
}
