variable "resource_group_name" {
  type = string
}
# key is the public ip name
variable "pub_ips" {
  type = map(object({
    allocation         = string
    sku                = string
    label              = string
  }))
  description = "needed public ips"
}

variable "tags" {
  type = map(string)
}

variable "pip_name" {
  type = string
}
variable "location" {
  type = string
}