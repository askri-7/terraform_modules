variable "key_vault_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}
variable "location" {
  type = string
}
variable "vm_principal_id" {
 type = string 
}

variable "workflow_identity_principal_id" {
  type = string
}

variable "terraform_admin_object_id" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "admin_email" {
  type      = string
  sensitive = true
}

variable "admin_password" {
  type      = string
  sensitive = true
}


variable "github_client_secret" {
  type      = string
  sensitive = true
}




variable "google_client_secret" {
  type      = string
  sensitive = true
}


variable "smtp_pass" {
  type      = string
  sensitive = true
}
