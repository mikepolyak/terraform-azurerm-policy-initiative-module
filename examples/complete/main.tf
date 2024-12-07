# File: examples/complete/main.tf
provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"  # Dev subscription
}

provider "azurerm" {
  alias           = "prod"
  features {}
  subscription_id = "11111111-1111-1111-1111-111111111111"  # Prod subscription
}

provider "azurerm" {
  alias           = "management"
  features {}
  subscription_id = "22222222-2222-2222-2222-222222222222"  # Management subscription
}

# Deploy policies using the module
module "policy_initiatives" {
  source = "../../modules/initiative"
  
  providers = {
    azurerm.target = azurerm  # Default provider for resource group lookups
  }

  assignments_config_file = "${path.module}/../../assignments/policy-assignments.json"
  module_enabled         = true
}

# Output the created assignments for reference
output "policy_assignments" {
  description = "Map of created policy assignments"
  value = {
    resource_groups = module.policy_initiatives.resource_group_assignments
    subscriptions  = module.policy_initiatives.subscription_assignments
    management_groups = module.policy_initiatives.management_group_assignments
  }
}