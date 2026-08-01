variable "resource_group_name" {
    type = string
  
}

variable "postgresql_name" {
  type        = string
}


variable "location" {
  type        = string
}

variable "private_dns" {
  type        = string
}

variable "virtual_network_id" {
  type        = string
}

variable "delegated_subnet_id" {
  type        = string
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
variable "postgresql_administrator_password" {
  type = string
  sensitive = true
}

variable "postgresql_administrator_login" {
  type = string
  sensitive = true
}