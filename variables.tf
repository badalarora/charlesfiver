variable "storage_account_name" {
  type = string
}
# locals {
#   resource_group="app-grp"
#   location="North Europe"
# }
variable "resource_group" {
  type = map
    default = {
    dev  = "dev-rg"
    test = "test-rg"
    prod = "prod-rg"
  }
}
variable "location" {
  type = string
}