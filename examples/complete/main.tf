# File: examples/complete/main.tf
provider "azurerm" {
  features {}
  subscription_id = "a9d881ca-f5c0-42cc-9670-946ef3155dfa"  # Dev subscription
}

provider "azurerm" {
  alias           = "prod"
  features {}
  subscription_id = "a9d881ca-f5c0-42cc-9670-946ef3155dfa"  # Prod subscription
}

provider "azurerm" {
  alias           = "management"
  features {}
  subscription_id = "a9d881ca-f5c0-42cc-9670-946ef3155dfa"  # Management subscription
}

# Deploy policies using the module
module "policy_initiatives" {
  source = "../../modules/initiative"
  
  providers = {
    azurerm.target = azurerm
  }

  # Use absolute or normalized relative path
  assignments_config_file = "${path.module}/../../assignments/policy-assignments.json"
  initiatives_base_path   = abspath("${path.module}/../..") # Convert to absolute path
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