variable "resource_group_name" {
  type = string
}
# key is the public ip name
variable "pip_allocation" {
  type= string
}
variable "pip_sku" {
  type = string
}
variable "tags" {
  type = map(string)
}
variable "location" {
  type = string
}
variable "pip_name" {
  type = string
}

variable "label" {
  type= string
  
}