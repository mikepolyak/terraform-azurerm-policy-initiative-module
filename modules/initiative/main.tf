# File: modules/initiative/main.tf

# Local variable validations
locals {
  # Parse and validate the assignments configuration
  assignments_config = jsondecode(file(var.assignments_config_file))

  # Flatten assignments and targets for easier processing
  flattened_assignments = flatten([
    for assignment in local.assignments_config.assignments : [
      for target in assignment.targets : {
        name        = assignment.name
        initiative  = assignment.initiative
        environment = assignment.environment
        scope_type  = target.scope_type

        # Handle different scope types
        subscription_id     = try(target.subscription_id, null)
        resource_group_name = try(target.resource_group_name, null)
        management_group_id = try(target.management_group_id, null)

        exemptions = try(assignment.exemptions, [])
      }
    ]
  ])

  # Group assignments by scope type
  assignments_by_scope = {
    rg  = [for a in local.flattened_assignments : a if a.scope_type == "rg"]
    sub = [for a in local.flattened_assignments : a if a.scope_type == "sub"]
    mg  = [for a in local.flattened_assignments : a if a.scope_type == "mg"]
  }

  # Validation checks
  validate_scope_types = alltrue([
    for assignment in local.flattened_assignments :
    contains(["rg", "sub", "mg"], assignment.scope_type)
  ])

  validate_required_fields = alltrue([
    for assignment in local.flattened_assignments :
    can(assignment.name) && can(assignment.initiative) && can(assignment.environment)
  ])
}

# Generate unique identifiers for various resources to ensure consistent naming
resource "random_uuid" "policy" {
  for_each = var.module_enabled ? {
    for assignment in local.assignments_config.assignments : assignment.name => assignment
  } : {}
}

resource "random_uuid" "exemptions" {
  count = var.module_enabled ? 1 : 0
}

resource "random_uuid" "assignment" {
  for_each = var.module_enabled ? {
    for assignment in local.flattened_assignments :
    "${assignment.name}-${coalesce(
      assignment.subscription_id,
      assignment.management_group_id,
      "${assignment.subscription_id}-${assignment.resource_group_name}"
    )}" => assignment
  } : {}
}

# Resource group data source to validate existence and fetch properties
data "azurerm_resource_group" "targets" {
  for_each = var.module_enabled ? {
    for assignment in local.assignments_by_scope.rg :
    "${assignment.name}-${assignment.resource_group_name}" => assignment
    if can(assignment.subscription_id) # Only try to fetch if we have a subscription ID
  } : {}

  provider = azurerm.target # Direct reference to the target provider
  name     = each.value.resource_group_name
}

# Create custom policy definitions based on the provided policy files
resource "azurerm_policy_definition" "custom" {
  for_each = var.module_enabled ? {
    for pair in flatten([
      for assignment in local.assignments_config.assignments :
      [
        for policy_key, policy in yamldecode(file(assignment.initiative)).policies :
        {
          key = "${assignment.name}-${policy_key}"
          value = {
            initiative   = assignment.initiative
            policy_key   = policy_key
            policy       = policy
            file_content = jsondecode(file(format("%s/%s", dirname(assignment.initiative), policy.file)))
            assignment   = assignment # Include the full assignment object
          }
        }
        if policy.type == "Custom"
      ]
    ]) : pair.key => pair.value
  } : {}

  name         = random_uuid.policy[each.value.initiative].result
  policy_type  = "Custom"
  mode         = try(each.value.file_content.properties.mode, "All")
  display_name = try(each.value.file_content.properties.displayName, each.value.policy_key)
  description  = try(each.value.file_content.properties.description, "Custom policy definition")

  metadata   = jsonencode(try(each.value.file_content.properties.metadata, {}))
  parameters = jsonencode(try(each.value.file_content.properties.parameters, {}))
  policy_rule = templatefile(
    format("%s/%s", dirname(each.value.initiative), each.value.policy.file),
    {
      effect = try(
        each.value.policy[each.value.assignment.environment].effect,
        each.value.policy.default.effect
      )
    }
  )
}

# Reference existing built-in policy definitions
data "azurerm_policy_definition" "builtin" {
  for_each = var.module_enabled ? {
    for pair in flatten([
      for assignment in local.assignments_config.assignments :
      [
        for policy_key, policy in yamldecode(file(assignment.initiative)).policies :
        {
          key   = "${assignment.name}-${policy_key}"
          value = policy
        }
        if policy.type == "BuiltIn"
      ]
    ]) : pair.key => pair.value
  } : {}

  display_name = each.value.id
}


# Combine all policy definitions (both custom and built-in) for easier reference
locals {
  all_policies = merge(
    {
      for k, v in azurerm_policy_definition.custom : k => {
        id   = v.id
        type = "Custom"
      }
    },
    {
      for k, v in data.azurerm_policy_definition.builtin : k => {
        id   = v.id
        type = "BuiltIn"
      }
    }
  )
}

# Create policy initiatives (policy sets) that group related policies
resource "azurerm_policy_set_definition" "this" {
  for_each = var.module_enabled ? {
    for assignment in local.assignments_config.assignments :
    assignment.name => {
      initiative  = assignment.initiative
      environment = assignment.environment
    }
  } : {}

  name         = random_uuid.policy[each.key].result
  policy_type  = "Custom"
  display_name = yamldecode(file(each.value.initiative)).display_name
  description  = yamldecode(file(each.value.initiative)).description

  dynamic "policy_definition_reference" {
    for_each = yamldecode(file(each.value.initiative)).policies

    content {
      policy_definition_id = local.all_policies["${each.key}-${policy_definition_reference.key}"].id
      parameter_values = jsonencode(
        try(
          policy_definition_reference.value[each.value.environment].parameters,
          policy_definition_reference.value.default.parameters,
          {}
        )
      )
    }
  }
}

# Assign policies at resource group scope
resource "azurerm_resource_group_policy_assignment" "this" {
  for_each = var.module_enabled ? {
    for assignment in local.assignments_by_scope.rg :
    "${assignment.name}-${assignment.resource_group_name}" => assignment
  } : {}

  name                 = random_uuid.assignment[each.key].result
  resource_group_id    = data.azurerm_resource_group.targets[each.key].id
  policy_definition_id = azurerm_policy_set_definition.this[each.value.name].id
}

# Assign policies at subscription scope
resource "azurerm_subscription_policy_assignment" "this" {
  for_each = var.module_enabled ? {
    for assignment in local.assignments_by_scope.sub :
    "${assignment.name}-${assignment.subscription_id}" => assignment
  } : {}

  name                 = random_uuid.assignment[each.key].result
  subscription_id      = each.value.subscription_id
  policy_definition_id = azurerm_policy_set_definition.this[each.value.name].id
}

# Assign policies at management group scope
resource "azurerm_management_group_policy_assignment" "this" {
  for_each = var.module_enabled ? {
    for assignment in local.assignments_by_scope.mg :
    "${assignment.name}-${assignment.management_group_id}" => assignment
  } : {}

  name                 = random_uuid.assignment[each.key].result
  management_group_id  = each.value.management_group_id
  policy_definition_id = azurerm_policy_set_definition.this[each.value.name].id
}

# Consolidate all assignments for easier reference in exemptions
locals {
  assignments = {
    rg  = azurerm_resource_group_policy_assignment.this
    sub = azurerm_subscription_policy_assignment.this
    mg  = azurerm_management_group_policy_assignment.this
  }
}

# Create policy exemptions at resource group scope
resource "azurerm_resource_group_policy_exemption" "this" {
  for_each = var.module_enabled ? {
    for i in flatten([
      for assignment in local.assignments_by_scope.rg : [
        for exemption in try(assignment.exemptions, []) : {
          key = "${assignment.name}-${exemption.name}"
          value = {
            assignment_key    = "${assignment.name}-${assignment.resource_group_name}"
            resource_group_id = data.azurerm_resource_group.targets["${assignment.name}-${assignment.resource_group_name}"].id
            category          = exemption.category
            risk_id           = exemption.risk_id
          }
        }
      ]
    ]) : i.key => i.value
  } : {}

  name                 = "${random_uuid.exemptions[0].result}-${each.key}"
  policy_assignment_id = local.assignments.rg[each.value.assignment_key].id
  resource_group_id    = each.value.resource_group_id
  exemption_category   = each.value.category
  description          = jsonencode({ "risk_id" : each.value.risk_id })
}

# Create policy exemptions at subscription scope
resource "azurerm_subscription_policy_exemption" "this" {
  for_each = var.module_enabled ? {
    for i in flatten([
      for assignment in local.assignments_by_scope.sub : [
        for exemption in try(assignment.exemptions, []) : {
          key = "${assignment.name}-${exemption.name}"
          value = {
            assignment_key  = "${assignment.name}-${assignment.subscription_id}"
            subscription_id = assignment.subscription_id
            category        = exemption.category
            risk_id         = exemption.risk_id
          }
        }
      ]
    ]) : i.key => i.value
  } : {}

  name                 = "${random_uuid.exemptions[0].result}-${each.key}"
  policy_assignment_id = local.assignments.sub[each.value.assignment_key].id
  subscription_id      = each.value.subscription_id
  exemption_category   = each.value.category
  description          = jsonencode({ "risk_id" : each.value.risk_id })
}

# Create policy exemptions at management group scope
resource "azurerm_management_group_policy_exemption" "this" {
  for_each = var.module_enabled ? {
    for i in flatten([
      for assignment in local.assignments_by_scope.mg : [
        for exemption in try(assignment.exemptions, []) : {
          key = "${assignment.name}-${exemption.name}"
          value = {
            assignment_key      = "${assignment.name}-${assignment.management_group_id}"
            management_group_id = assignment.management_group_id
            category            = exemption.category
            risk_id             = exemption.risk_id
          }
        }
      ]
    ]) : i.key => i.value
  } : {}

  name                 = "${random_uuid.exemptions[0].result}-${each.key}"
  policy_assignment_id = local.assignments.mg[each.value.assignment_key].id
  management_group_id  = each.value.management_group_id
  exemption_category   = each.value.category
  description          = jsonencode({ "risk_id" : each.value.risk_id })
}