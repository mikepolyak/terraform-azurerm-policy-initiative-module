# File: modules/initiative/variables.tf

variable "assignments_config_file" {
  type        = string
  description = <<-DESC
    (Required) Path to the JSON file containing policy assignments configuration.
    This file should contain the complete configuration for all policy assignments
    including initiative references, environments, and target scopes.
  DESC
}

variable "module_enabled" {
  type        = bool
  description = "(Optional) Whether to create resources in this module. Defaults to true."
  default     = true
}

