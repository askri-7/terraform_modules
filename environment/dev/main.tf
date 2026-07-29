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
  identity_name = "${var.naming.project}-${var.naming.environment}-identity"
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
  tags                = var.tags
}

module "vnet" {
  source                   = "../../modules/Vnet"
  resource_group_name      = data.azurerm_resource_group.rg.name
  vnet_name                = "${var.naming.project}-${var.naming.environment}-vnet"
  virtual_network_location = var.location
  address_space            = var.address_space
  ddos_protection_plan     = var.ddos_protection_plan
  dynamic_subnets          = var.dynamic_subnets
  tags                     = var.tags
}

module "public_ip" {
  for_each = {
  for k, v in var.virtual_machines : k => v
  if v.has_public_ip
}
  source              = "../../modules/public_ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  pip_name =  "${var.naming.project}-${var.naming.environment}-${each.key}-pip"
  location = var.location
  pip_allocation = each.value.public_ip.allocation
  pip_sku = each.value.public_ip.sku
  tags                = var.tags
}


module "vm" {
  source   = "../../modules/VM"
  for_each = var.virtual_machines

  vm_name             = "${var.naming.project}-${var.naming.environment}-${each.key}-vm"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  ssh_public_key      = var.ssh_public_key

  cloud_init = filebase64("../../cloud-init/${each.key}.sh")

  nic_vars = {
    subnet_id = module.vnet.subnet_ids[each.value.subnet_key]
   pub_ip_id = each.value.has_public_ip ? module.public_ip[each.key].id : null
  }

  ip_conf          = each.value.ip_conf
  vm_metadata      = each.value.vm_metadata
  os_disk          = each.value.os_disk
  source_image     = each.value.source_image
  boot_diagnostics = each.value.boot_diagnostics
  disks            = each.value.disks
  tags             = var.tags
}