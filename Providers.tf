terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.82.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "880d5397-7faf-45d3-9764-9d82bac0d7f9"
  client_id       = "62e0f4e6-d0b0-4262-85b7-228bc495e6ff"
  client_secret   = "N.Z8Q~C4N_6CIq-itYfSv5Y7_uk9KM0ZcRyP.bCg"
  tenant_id       = "791396d9-935c-4a36-bf54-10c2bfff52d6"
  features {}
}