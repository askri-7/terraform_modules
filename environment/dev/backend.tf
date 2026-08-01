terraform {
  backend "azurerm" {
    resource_group_name  = "isra-rg-01"
    storage_account_name = "terrafstorageaccount01"
    container_name       = "internshipdevtfstate"
    key                  = "internship-dev-frctl.tfstate"
    use_azuread_auth     = true
    use_oidc             = true
  }
}