# terraform/variables.tf
variable "yc_token" {
  type = string
}

variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "ssh_pub" {
  type    = string
}

variable "db_user" {
  description = "DB user"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "DB password"
  type        = string
  sensitive   = true
}

variable "db_database" {
  description = "DB database"
  type        = string
}

variable "yc_postgresql_version" {
  description = "DB yc postgresql version"
  type        = string
}

variable "domen" {
  description = "Domen name"
  type        = string
}

variable "network_name" {
  description = "Network name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

variable "path_to_file" {
  description = "Path to ssh file"
  type        = string
  sensitive   = true
}