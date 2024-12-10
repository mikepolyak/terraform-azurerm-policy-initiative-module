# File: modules/initiative/variables.tf

variable "assignments_config_file" {
  type        = string
  description = <<-DESC
    (Required) Path to the JSON file containing policy assignments configuration.
    This file should contain the complete configuration for all policy assignments
    including initiative references, environments, and target scopes.
  DESC
}

variable "initiatives_base_path" {
  type        = string
  description = <<-DESC
    (Required) Base path where initiative files are located. This should be an absolute path 
    or relative to your root module. This helps the module locate your initiative and policy 
    files correctly regardless of where the module is being used from.
  DESC
}

variable "module_enabled" {
  type        = bool
  description = "(Optional) Whether to create resources in this module. Defaults to true."
  default     = true
}