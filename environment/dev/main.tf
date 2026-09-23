data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_storage_account" "sta" {
  name                = var.storage_account_name
  resource_group_name = data.azurerm_resource_group.rg.name
}




module "github_actions_identity" {
  source              = "../../modules/workflow_identity"
  identity_name       = "${var.naming.project}-${var.naming.environment}-workflow-identity"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  role_assignments = {

    deployment = {
      role_name = "Contributor"
      scope     = data.azurerm_resource_group.rg.id
    }

    terraform_state = {
      role_name = "Storage Blob Data Contributor"
      scope     = data.azurerm_storage_account.sta.id
    }

  }
  audience_name      = local.default_audience_name
  issuer_url         = local.github_issuer_url
  federated_subjects = var.federated_subjects
  tags               = var.tags
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
  source              = "../../modules/public_ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  pip_name            = "${var.naming.project}-${var.naming.environment}-webapp-pip"
  location            = var.location
  pub_ips             = var.pub_ips # map of public ip
  tags                = var.tags
}

#### one vm one cloud init one host server

module "vm" {
  source = "../../modules/VM"

  vm_name             = "${var.naming.project}-${var.naming.environment}-vm"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  ssh_public_key      = var.ssh_public_key

  ### custum config

  cloud_init = base64encode(templatefile(var.cloud_init_path, {
    domain_name         = var.domain_name
    frontend_url        = local.frontend_url
    api_url             = local.api_url
    github_callback_url = local.github_callback_url
    google_callback_url = local.google_callback_url

    github_client_id = var.github_client_id
    google_client_id = var.google_client_id

    key_vault_url  = module.keyvault.key_vault_uri
    key_vault_name = module.keyvault.key_vault_name

    smtp_host = var.smtp_host
    smtp_port = var.smtp_port
    smtp_user = var.smtp_user
    smtp_from = var.smtp_from

    db_name              = var.db_name
    db_user              = var.db_user
    db_host              = var.db_host
    db_port              = var.db_port
    db_pool_max          = var.db_pool_max
    db_timeout           = var.db_timeout
    db_idle_timeout      = var.db_idle_timeout
    db_statement_timeout = var.db_statement_timeout
   
    data_disk_lun      = var.disks["data"].lun
    app_repo_url       = var.app_repo_url
    app_branch         = var.app_branch
    dockerhub_username = var.dockerhub_username
    image_tag          = var.image_tag
    vm_username        = var.virtual_machine_vars.admin_username


  }))



  ###  nic 

  nic_vars = {
    subnet_id = module.vnet.subnet_ids["webapp"]
    pub_ip_id = module.public_ip.public_ip_ids["webapp"]
  }

  ip_conf = var.ip_conf
  ## vm config
  virtual_machine_vars = var.virtual_machine_vars
  source_image         = var.source_image
  os_disk              = var.os_disk
  boot_diagnostics     = var.boot_diagnostics
  disks                = var.disks
  tags                 = var.tags

}

module "keyvault" {
  source                         = "../../modules/keyvault"
  key_vault_name                 = "${var.naming.project}-${var.naming.environment}-kv"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  vm_principal_id                = module.vm.principal_id
  workflow_identity_principal_id = module.github_actions_identity.user_assinged_identity_principal_id
  terraform_admin_object_id      = var.terraform_admin_object_id
  jwt_secret                     = var.jwt_secret
  admin_email                    = var.admin_email
  admin_password                 = var.admin_password
  db_password                    = var.db_password
  smtp_pass                      = var.smtp_pass
  google_client_secret           = var.google_client_secret
  github_client_secret           = var.github_client_secret
  tags                           = var.tags

}