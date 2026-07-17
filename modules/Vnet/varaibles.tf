variable "virtual_network_name" {
    type = string
    description = "Vnet name"  
}
variable "virtual_network_location" {
    type = string
    description = "Vnet location"  
}

variable "address_space" {
    type = list(string)
    description = "address space value"  
}

variable "resource_group_name" {
    type = string
    description = "resource group name"  
}

variable "ddos_protection_plan" {
  type = object({
    enable = bool
    id     = string
  })
  default = null
  description = "ddos_plan"
}

variable "subnet_name" {
    type = string
    description = " subnet name"  
}

variable "address_prefixes" {
    type =  list(string)
    description = "subnet adress"
}



variable "nsg_name" {
  type = string
  description = "security group name."
}


variable "security_rules" {
  type = string
  description = "security rules name"
}


variable "sr_priority" {
  type = number
  description = "security rules priority"
}

variable "sr_direction" {
  type  = string
  description = "direction of the rule (Inbound or Outbound)."
}

variable "sr_access" {
  type = string
  description = "Access for the rule (Allow or Deny)."
}

variable "sr_protocol" {
  type = string
  description = "Protocol (Tcp, Udp, Icmp, or *)."
}

variable "sr_source_port_range" {
  type = string
  description = "source port or port range."
}

variable "sr_destination_port_range" {
  type = string
  description = "Destination port or port range."
}

variable "source_address_prefix" {
  type = string
  description = "source address prefix."
}

variable "destination_address_prefix" {
  type = string
  description = "destination address prefix."
}