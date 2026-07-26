variable "location" {
  type = string
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
variable "resource_group_name" {
  type = string
}


 variable "federated_subjects" {
   type = map(string)
 }
 variable "audience_name" {
   type =  string
 }
 variable "issuer_url" {
   type = string
 }
 variable "role_assignments" {
   type = map(object({
       role_name = string
       scope = string
   }))
 }