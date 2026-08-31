variable "rg_name" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vnet_address_space" {
  type = list(string)
}

variable "app_cidr" {
  type = list(string)
}

variable "web_cidr" {
  type = list(string)
}

variable "mgmt_cidr" {
  type = list(string)
}
