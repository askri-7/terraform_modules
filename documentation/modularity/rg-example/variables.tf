

variable "resource_group_name"  {
    type = string
    default = "internship-web-rg"
    description = "a fixed resource name"
 
}

variable "resource_group_location" {
     type= string
     default= "westus2"  
     description = "the location of the resource groupe"
     }