# Global
resource_group_name  = "isra-rg-01"
storage_account_name = "terrafstorageaccount01"
location             = "FranceCentral"

naming = {
  environment = "dev"
  project     = "internship-web"
}

federated_subjects = {
  onpush  = "repo:askri-7/terraform_modules:ref:refs/heads/release/multi-vm"
  onpullR = "repo:askri-7/terraform_modules:pull_request"
  onapply = "repo:askri-7/terraform_modules:environment:dev"
}

# Virtual network
address_space = [
  "10.0.0.0/16"
]

ddos_protection_plan = null

# One subnet per tier, each with its own scoped rules
dynamic_subnets = {
  frontend = {
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

  backend = {
    cidr_block = "10.0.2.0/24"
    security_rules = [
      {
        name                       = "Allow-App-From-Frontend"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8080"        # adjust to your backend's actual port
        source_address_prefix      = "10.0.1.0/24" # only from frontend subnet
        destination_address_prefix = "*"
      },
      {
        name                       = "Allow-SSH-Internal"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "10.0.0.0/16" # only from within the VNet, not internet
        destination_address_prefix = "*"
      }
    ]
  }
  database = {
    cidr_block = "10.0.3.0/24"

    delegation = {
      name = "postgres-flexible-server"

      service_name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }

    security_rules = [
      {
        name                       = "Allow-Postgres-From-Backend"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "5432"
        source_address_prefix      = "10.0.2.0/24"
        destination_address_prefix = "*"
      }
    ]
  }

}



tags = {
  environment = "dev"
  owner       = "tmtrack"
  costcenter  = "internshsip"
}

# Virtual Machines
virtual_machines = {

  frontend = {
    subnet_key    = "frontend"
    has_public_ip = true
    public_ip = {
      allocation = "Static"
      sku        = "Standard"
    }
    source_image = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
    boot_diagnostics = {
      enabled             = false
      storage_account_uri = null
    }
    vm_metadata = {
      size           = "Standard_B2s_v2"
      admin_username = "evil"
      computer_name  = "frontend"
    }
    ip_conf = {
      name       = "ipconfig1"
      allocation = "Dynamic"
    }
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Premium_LRS"
    }
    disks = {}
  }

  backend = {
    subnet_key    = "backend"
    has_public_ip = false
    public_ip     = null
    source_image = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
    boot_diagnostics = {
      enabled             = false
      storage_account_uri = null
    }
    vm_metadata = {
      size           = "Standard_B2s_v2"
      admin_username = "evil"
      computer_name  = "backend"
    }
    ip_conf = {
      name       = "ipconfig1"
      allocation = "Dynamic"
    }
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Premium_LRS"
    }
    disks = {}
  }

}

postgresql_metadata = {
  version = "16"
  zone    = "1"

  storage_mb   = 32768
  storage_tier = "P4"

  sku_name = "B_Standard_B1ms"
}
private_dns = "postgres.database.azure.com"