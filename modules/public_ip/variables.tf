variable "resource_group_name" {
     type = string
} 
# key is the public ip name
variable "pub_ips" {
     type = map(object({    
     public_ip_location = string
     allocation= string
     sku = string
     }))
    description = "needed public ips"
}

variable "tags" {
  type = map(string)
}
variable "naming" {
  type = object({
     project  = string
     environment = string

  })
}