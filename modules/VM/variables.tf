variable "resource_group_name" {
  type = string
}



variable "location" {
  type        = string
  description = "location of both nic + vm"

}
variable "nic_vars" {
  type = object({
    subnet_id = string
    pub_ip_id = string
  })
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


variable "ssh_public_key" {
  type = string
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

variable "disks" {
  type = map(object({
    storage_account_type = string
    create_option        = string
    disk_size_gb         = number
    lun                  = number
    caching              = string
    network_access_policy= string
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