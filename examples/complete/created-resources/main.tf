# Random UUIDs for resource naming
resource "random_uuid" "policy" {
  for_each = {
    "security-baseline-dev"  = "security baseline dev"
    "security-baseline-prod" = "security baseline prod"
    "governance-dev"         = "governance dev"
  }
}

resource "random_uuid" "exemptions" {
  count = 1
}

resource "random_uuid" "assignment" {
  for_each = {
    "security-baseline-dev-00000000-0000-0000-0000-000000000000" = "dev subscription assignment"
    "security-baseline-prod-mg-production"                       = "prod mg assignment"
    "governance-dev-rg-application-dev"                          = "dev rg assignment"
  }
}

# Custom Policy Definitions
resource "azurerm_policy_definition" "custom" {
  for_each = {
    "security-baseline-dev-StorageEncryption" = {
      name         = random_uuid.policy["security-baseline-dev"].result
      policy_type  = "Custom"
      mode         = "Indexed"
      display_name = "Storage encryption should be enabled"
      description  = "Ensures that encryption is enabled for Azure Storage accounts."
      policy_rule  = file("../../../policies/storage/encryption_required.json")
      effect       = "audit"
    }
    "security-baseline-prod-StorageEncryption" = {
      name         = random_uuid.policy["security-baseline-prod"].result
      policy_type  = "Custom"
      mode         = "Indexed"
      display_name = "Storage encryption should be enabled"
      description  = "Ensures that encryption is enabled for Azure Storage accounts."
      policy_rule  = file("../../../policies/storage/encryption_required.json")
      effect       = "deny"
    }
    "security-baseline-dev-AllowedLocations" = {
      name         = random_uuid.policy["security-baseline-dev"].result
      policy_type  = "Custom"
      mode         = "All"
      display_name = "Allowed locations for resource deployment"
      description  = "Specifies the allowed locations where resources can be deployed."
      policy_rule  = file("../../../policies/compute/allowed_locations.json")
      effect       = "audit"
    }
    "security-baseline-prod-AllowedLocations" = {
      name         = random_uuid.policy["security-baseline-prod"].result
      policy_type  = "Custom"
      mode         = "All"
      display_name = "Allowed locations for resource deployment"
      description  = "Specifies the allowed locations where resources can be deployed."
      policy_rule  = file("../../../policies/compute/allowed_locations.json")
      effect       = "deny"
    }
    "governance-dev-RequiredTags" = {
      name         = random_uuid.policy["governance-dev"].result
      policy_type  = "Custom"
      mode         = "Indexed"
      display_name = "Require specified tags on resources"
      description  = "Ensures that specified tags are present on all resources."
      policy_rule  = file("../../../policies/tags/required_tags.json")
      effect       = "audit"
    }
  }

  name         = each.value.name
  policy_type  = each.value.policy_type
  mode         = each.value.mode
  display_name = each.value.display_name
  description  = each.value.description
  policy_rule  = each.value.policy_rule
}

# Built-in Policy References
data "azurerm_policy_definition" "builtin" {
  for_each = {
    "governance-dev-ResourceNaming" = {
      display_name = "1e30110a-5ceb-460c-a204-c1c3969c6d62"
    }
    "security-baseline-LogAnalytics" = {
      display_name = "a70ca396-0a34-413a-88e1-0e32778d9286"
    }
  }

  display_name = each.value.display_name
}

# Policy Initiatives (Policy Sets)
resource "azurerm_policy_set_definition" "this" {
  for_each = {
    "security-baseline-dev" = {
      name         = random_uuid.policy["security-baseline-dev"].result
      display_name = "Security Baseline Initiative"
      description  = "Establishes a basic security baseline across Azure resources"
    }
    "security-baseline-prod" = {
      name         = random_uuid.policy["security-baseline-prod"].result
      display_name = "Security Baseline Initiative"
      description  = "Establishes a basic security baseline across Azure resources"
    }
    "governance-dev" = {
      name         = random_uuid.policy["governance-dev"].result
      display_name = "Core Governance Initiative"
      description  = "Implements core governance controls for resource management"
    }
  }

  name         = each.value.name
  policy_type  = "Custom"
  display_name = each.value.display_name
  description  = each.value.description

  dynamic "policy_definition_reference" {
    for_each = each.key == "security-baseline-dev" ? {
      StorageEncryption = azurerm_policy_definition.custom["security-baseline-dev-StorageEncryption"].id
      AllowedLocations  = azurerm_policy_definition.custom["security-baseline-dev-AllowedLocations"].id
      LogAnalytics      = data.azurerm_policy_definition.builtin["security-baseline-LogAnalytics"].id
      } : each.key == "security-baseline-prod" ? {
      StorageEncryption = azurerm_policy_definition.custom["security-baseline-prod-StorageEncryption"].id
      AllowedLocations  = azurerm_policy_definition.custom["security-baseline-prod-AllowedLocations"].id
      LogAnalytics      = data.azurerm_policy_definition.builtin["security-baseline-LogAnalytics"].id
      } : {
      RequiredTags   = azurerm_policy_definition.custom["governance-dev-RequiredTags"].id
      ResourceNaming = data.azurerm_policy_definition.builtin["governance-dev-ResourceNaming"].id
    }

    content {
      policy_definition_id = policy_definition_reference.value
    }
  }
}

# Policy Assignments
resource "azurerm_subscription_policy_assignment" "this" {
  for_each = {
    "security-baseline-dev" = {
      name            = random_uuid.assignment["security-baseline-dev-00000000-0000-0000-0000-000000000000"].result
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }

  name                 = each.value.name
  subscription_id      = each.value.subscription_id
  policy_definition_id = azurerm_policy_set_definition.this[each.key].id
}

resource "azurerm_management_group_policy_assignment" "this" {
  for_each = {
    "security-baseline-prod" = {
      name                = random_uuid.assignment["security-baseline-prod-mg-production"].result
      management_group_id = "mg-production"
    }
  }

  name                 = each.value.name
  management_group_id  = each.value.management_group_id
  policy_definition_id = azurerm_policy_set_definition.this[each.key].id
}

resource "azurerm_resource_group_policy_assignment" "this" {
  for_each = {
    "governance-dev" = {
      name              = random_uuid.assignment["governance-dev-rg-application-dev"].result
      resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-application-dev"
    }
  }

  name                 = each.value.name
  resource_group_id    = each.value.resource_group_id
  policy_definition_id = azurerm_policy_set_definition.this[each.key].id
}

# Policy Exemptions
resource "azurerm_resource_group_policy_exemption" "this" {
  for_each = {
    "governance-dev-legacy-app" = {
      name              = "${random_uuid.exemptions[0].result}-legacy-app"
      resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-application-dev"
      category          = "Waiver"
      risk_id           = "R-001"
    }
  }

  name                 = each.value.name
  resource_group_id    = each.value.resource_group_id
  policy_assignment_id = azurerm_resource_group_policy_assignment.this["governance-dev"].id
  exemption_category   = each.value.category
  description          = jsonencode({ "risk_id" : each.value.risk_id })
}