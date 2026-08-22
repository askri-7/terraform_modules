variable "resource_group_name" {
  type        = string
  description = "the resource group name"
}

variable "federated_subjects" {
  type = map(string)
}



variable "storage_account_name" {
  type = string

}

# vnet vars


variable "address_space" {
  type        = list(string)
  description = "address space value"
}



variable "ddos_protection_plan" {
  type = object({
    enable = bool
    id     = string
  })
  default     = null
  description = "ddos_plan"
}


variable "dynamic_subnets" {
  type = map(object({ cidr_block = string
    security_rules = list(object({ name = string
      priority               = number
      direction              = string
      access                 = string
      protocol               = string
      source_port_range      = string
      destination_port_range = string
      source_address_prefix  = string
    destination_address_prefix = string }))
  }))
  description = "map of dynamic subnets security rule block as dynamic var"
}

# vm vars 


variable "pub_ips" {
  type = map(object({
    public_ip_location = string
    allocation         = string
    sku                = string
    label              = string
  }))
  description = "needed public ips"
}

variable "location" {
  type        = string
  description = "location of both nic + vm"

}


variable "ip_conf" {
  type = object({
    name       = string
    allocation = string
  })
  # validate inputs
  validation {
    condition     = contains(["Dynamic", "Static"], var.ip_conf.allocation)
    error_message = "allocation must be Dynamic or Static."
  }

}

variable "virtual_machine_vars" {
  type = object({
    size           = string
    admin_username = string
    computer_name  = string
  })
}
variable "os_disk" {
  type = object({

    caching              = string
    storage_account_type = string

  })
  description = "os_disk configuration"
}

variable "source_image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  description = "source image configuration"
}



variable "boot_diagnostics" {
  type = object({
    enabled             = bool
    storage_account_uri = optional(string)
  })

  default = {
    enabled = false
  }
  description = "boot diagnostics configuration"
}

variable "ssh_public_key" {
  type = string
}

variable "disks" {
  type = map(object({

    storage_account_type          = string
    create_option                 = string
    disk_size_gb                  = number
    lun                           = number
    caching                       = string
    public_network_access_enabled = bool
  }))
}
variable "tags" {
  type = map(string)
}

variable "naming" {
  type = object({
    project     = string
    environment = string

  })
}
variable "cloud_init_path" {
  type = string
}




# ═══════════════════════════════════════════
# APP CONFIGURATION (non-sensitive)
# ═══════════════════════════════════════════

variable "node_env" {
  type = string
}

variable "app_port" {
  type    = number
  default = 3000
}



# ═══════════════════════════════════════════
# DATABASE (non-sensitive tuning)
# ═══════════════════════════════════════════

variable "db_name" {
  type = string

}

variable "db_user" {
  type = string

}

variable "db_pool_max" {
  type = number

}

variable "db_timeout" {
  type = number

}

variable "db_idle_timeout" {
  type = number

}

variable "db_statement_timeout" {
  type = number

}

# ═══════════════════════════════════════════
# SECRETS (sensitive — never commit values)
# ═══════════════════════════════════════════

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "admin_email" {
  type      = string
  sensitive = true
}

variable "admin_password" {
  type      = string
  sensitive = true
}

# ═══════════════════════════════════════════
# OAUTH (public IDs + sensitive secrets)
# ═══════════════════════════════════════════

variable "github_client_id" {
  type = string
}

variable "github_client_secret" {
  type      = string
  sensitive = true
}


//
variable "google_client_id" {
  type = string
}

variable "google_client_secret" {
  type      = string
  sensitive = true
}



# ═══════════════════════════════════════════
# APP REPO
# ═══════════════════════════════════════════

variable "app_repo_url" {
  type = string

}

variable "app_branch" {
  type = string

}


variable "domain_name" {
  type    = string

}

variable "smtp_pass" {
  type      = string
  sensitive = true
}

variable "smtp_host" {
  type = string
}
variable "smtp_from" {
  type= string
  
}
variable "smtp_port" {
  type = number
}
variable "dockerhub_username" {
  type = string
}
