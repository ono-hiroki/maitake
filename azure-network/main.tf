# Azure Provider設定
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# リソースグループ
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.location

  tags = var.tags
}
