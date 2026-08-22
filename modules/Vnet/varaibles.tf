
variable "virtual_network_location" {
  type        = string
  description = "Vnet location"
}

variable "address_space" {
  type        = list(string)
  description = "address space value"
}

variable "resource_group_name" {
  type        = string
  description = "resource group name"
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


variable "tags" {
  type = map(string)
}

variable "vnet_name" {
  type = string
}

