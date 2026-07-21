variable "resource_group_name" {
     type = string
} 

variable "pub_ips" {
     type = map(object({
     public_ip_location = string
     allocation= string
     sku = string
     }))
    description = "needed public ips"
}
