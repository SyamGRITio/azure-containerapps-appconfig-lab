terraform {
  required_version = "~> 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.3"
    }

    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }
}
