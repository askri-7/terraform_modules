
# Global

resource_group_name  = "isra-rg-01"
storage_account_name = "terrafstorageaccount01"
location             = "francecentral"
naming = {
  environment = "dev"
  project     = "internship-web"
}


federated_subjects = {
  onpush  = "repo:askri-7/terraform_modules:ref:refs/heads/release/1vm"
  onpullR = "repo:askri-7/terraform_modules:pull_request"
  onapply = "repo:askri-7/terraform_modules:environment:dev"
}
# Virtual network


address_space = [
  "10.0.0.0/16"
]

ddos_protection_plan = null

dynamic_subnets = {
  webapp = {
    cidr_block = "10.0.1.0/24"

    security_rules = [
      {
        name                       = "Allow-HTTP"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
      },
      {
        name                       = "Allow-HTTPS"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
      },
      {
        name                       = "Allow-SSH"
        priority                   = 120
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
      }
    ]
  }

}

# Public IPs


pub_ips = {
  webapp = {
    public_ip_location = "FranceCentral"
    allocation         = "Static"
    sku                = "Standard"
  }
}

# NIC




ip_conf = {
  name       = "ipconfig1"
  allocation = "Dynamic"
}

# Virtual Machine

virtual_machine_vars = {

  size           = "Standard_B2s_v2"
  admin_username = "evil"
  computer_name  = "webapp"
}

# OS Disk


os_disk = {

  caching              = "ReadWrite"
  storage_account_type = "Premium_LRS"

}

# Ubuntu image


source_image = {
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy"
  sku       = "22_04-lts-gen2"
  version   = "latest"
}

# Boot Diagnostics


boot_diagnostics = {
  enabled             = false
  storage_account_uri = null
}
# disks

disks = {
  data = {
    storage_account_type          = "Standard_LRS"
    create_option                 = "Empty"
    disk_size_gb                  = 64
    lun                           = 0
    caching                       = "ReadWrite"
    public_network_access_enabled = false
  }
}


tags = {
  "environment" = "dev"
  "owner"       = "tmtrack"
  costcenter    = "internshsip"
}
cloud_init_path = "../../cloud-init/webapp.sh"


# Database connection tuning
db_pool_max          = 20
db_timeout           = 10000
db_idle_timeout      = 30000
db_statement_timeout = 30000

# Database user (non-sensitive)
db_user = "webapp_user"

# App config
#node_env     = "production"
node_env = "dev"
app_port     = 3000
frontend_url = "https://20.111.18.168"
db_name      = "secure_login_db"

# OAuth public IDs (not secrets)
github_client_id    = "Ov23liRZBFLPUkz5iiUz"
github_callback_url = "https://20.111.18.168/auth/github/callback"

google_client_id    = "508085257923-vtuio6f4qchko8beu3l9jkt905hgq33k.apps.googleusercontent.com"
google_callback_url = "https://20.111.18.168/auth/google/callback"

# Admin


# App repo
app_repo_url = "https://github.com/askri-7/secure-login-demo.git"
app_branch   = "main"  