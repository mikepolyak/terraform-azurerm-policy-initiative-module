terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = ">= 3.0.0"
      configuration_aliases = [azurerm.target] # Declare that we expect a provider named "target"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
  required_version = ">= 1.0.0"
}

# provider "azurerm" {
#   features {}
#   subscription_id = "00000000-0000-0000-0000-000000000000" # Default subscription
# }

# provider "azurerm" {
#   alias = "target"
#   features {}
#   subscription_id = "11111111-1111-1111-1111-111111111111" # Target subscription
# }