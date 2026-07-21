variable "resource_group_name" {
  type        = string
  description = "the resource group name"
}

variable "storage_account_name" {
  type = string

}
# vnet vars
variable "virtual_network_name" {
  type        = string
  description = "Vnet name"
}


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
  }))
  description = "needed public ips"
}

variable "location" {
  type        = string
  description = "location of both nic + vm"

}

variable "nic_name" {
  type = string

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
    name           = string
    size           = string
    admin_username = string
    computer_name  = string
  })
}
variable "os_disk" {
  type = object({
    name                 = string
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










