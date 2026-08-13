
# Global

resource_group_name  = "isra-rg-01"
storage_account_name = "terrafstorageaccount01"
location             = "FranceCentral"
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

  size           = "Standard_B4ms"
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
db_pool_max           = 20
db_timeout            = 10000
db_idle_timeout       = 30000
db_statement_timeout  = 30000


node_env     = "production"
app_port     = 3000
frontend_url = "https://yourdomain.com"

db_name      = "secure_login"


github_callback_url = "https://yourdomain.com/auth/github/callback"
google_callback_url = "https://yourdomain.com/auth/google/callback"

app_repo_url = "https://github.com/askri-7/secure-login-demo.git"
app_branch   = "main"