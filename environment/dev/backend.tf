terraform {
  backend "azurerm" {
    resource_group_name  = "isra-rg-01"
    storage_account_name = "terrafstorageaccount01"
    container_name       = "internshipdevmultivmtfstate"
    key                  = "internship-dev-multi-vm.tfstate"
    use_azuread_auth     = true
    use_oidc             = true
  }
}