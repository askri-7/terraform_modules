data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_storage_account" "sta" {
  name                = var.storage_account_name
  resource_group_name = data.azurerm_resource_group.rg.name
}




module "github_actions_identity" {
  source              = "../../modules/workflow_identity"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  role_assignments = {

  deployment = {
    role_name  = "Contributor"
    scope = data.azurerm_resource_group.rg.id
  }

  terraform_state = {
    role_name  = "Storage Blob Data Contributor"
    scope = data.azurerm_storage_account.sta.id
  }

}
  audience_name       = local.default_audience_name
  issuer_url          = local.github_issuer_url
  federated_subjects  = var.federated_subjects
  naming              = var.naming
  tags                = var.tags
}

module "vnet" {
  source                   = "../../modules/Vnet"
  resource_group_name      = data.azurerm_resource_group.rg.name
  virtual_network_location = var.location
  address_space            = var.address_space
  ddos_protection_plan     = var.ddos_protection_plan
  dynamic_subnets          = var.dynamic_subnets
  naming                   = var.naming
  tags                     = var.tags
}

module "public_ip" {
  source              = "../../modules/public_ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  pub_ips             = var.pub_ips
  naming              = var.naming
  tags                = var.tags
}
module "vm" {
  source = "../../modules/VM"

  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  ssh_public_key      = var.ssh_public_key

  nic_vars = {
    subnet_id = module.vnet.subnet_ids["frontend"]
    pub_ip_id = module.public_ip.public_ip_ids["frontend"]
  }

  ip_conf              = var.ip_conf
  virtual_machine_vars = var.virtual_machine_vars
  os_disk              = var.os_disk
  source_image         = var.source_image
  boot_diagnostics     = var.boot_diagnostics
  disks                = var.disks
  naming               = var.naming
  tags                 = var.tags
}

