terraform {
  backend "azurerm" {
    resource_group_name  = "isra-rg-01"
    storage_account_name = "terrafstorageaccount01"
    container_name       = "internshipdev3vmtfstate"
    key                  = "internship-dev-3vm.tfstate"
    use_azuread_auth     = true
     use_oidc = true
  }
}