variable "resource_group_name" {
  type        = string
 
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
    
    delegation = optional(object({
      name          = string
      service_name  = string
      actions       = list(string)
    }), null)
    
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

variable "location" {
  type        = string
  description = "location of both nic + vm"

}
variable "ssh_public_key" {
  type = string
  description = "secret"
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
variable "virtual_machines" {
  type = map(object({
    subnet_key    = string
    has_public_ip = bool

    public_ip = optional(object({
      allocation = string
      sku        = string
    }), null)
    source_image = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })
    boot_diagnostics = object({
      enabled             = optional(bool, false)
      storage_account_uri = optional(string)
    })
    vm_metadata = object({
      size           = string
      admin_username = string
      computer_name  = string
    })
    ip_conf = object({
      name       = string
      allocation = string
    })
    os_disk = object({
      caching              = string
      storage_account_type = string
    })
    disks = map(object({
      storage_account_type          = string
      create_option                 = string
      disk_size_gb                  = number
      lun                           = number
      caching                       = string
      public_network_access_enabled = bool
    }))
  }))
}

variable "postgresql_administrator_password" {
  type = string
  sensitive = true
}

variable "postgresql_administrator_login" {
  type = string
  sensitive = true
}
variable "postgresql_metadata" {
  description = "PostgreSQL Flexible Server configuration"

  type = object({
    version               = string
    zone                  = string
    storage_mb            = number
    storage_tier          = string
    sku_name              = string
  })

  sensitive = true
}

variable "private_dns" {
  type        = string
}


