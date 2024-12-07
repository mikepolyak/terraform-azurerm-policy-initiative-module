# File: modules/initiative/outputs.tf

output "policy_set_definitions" {
  description = "Map of created policy set definitions"
  value       = azurerm_policy_set_definition.this
}

output "resource_group_assignments" {
  description = "Map of policy assignments at resource group scope"
  value       = azurerm_resource_group_policy_assignment.this
}

output "subscription_assignments" {
  description = "Map of policy assignments at subscription scope"
  value       = azurerm_subscription_policy_assignment.this
}

output "management_group_assignments" {
  description = "Map of policy assignments at management group scope"
  value       = azurerm_management_group_policy_assignment.this
}