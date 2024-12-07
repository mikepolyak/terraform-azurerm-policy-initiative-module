# Azure Policy Initiative Module

This Terraform module helps organizations implement and manage Azure Policies at scale using a configuration-driven approach. Rather than managing individual policies through multiple Terraform resources, this module allows you to define your policy requirements in structured configuration files and handles the complexity of policy creation, initiative bundling, and assignment management for you.

## Understanding the Module Structure

When working with Azure Policies at scale, it's important to organize your policy definitions and assignments in a way that's both maintainable and understandable. This module uses a hierarchical structure that mirrors how Azure Policy components relate to each other:

The `policies` directory contains individual policy definitions organized by category (compute, network, storage, etc.). Think of these as your building blocks - the basic rules you want to enforce in your Azure environment. For example, a policy might require certain tags on resources or restrict the locations where resources can be deployed.

The `initiatives` directory holds YAML files that define policy initiatives (also known as policy sets). An initiative brings together multiple related policies under a single management unit. This is particularly useful when you want to implement a comprehensive governance strategy. For instance, a security baseline initiative might combine policies for encryption requirements, networking restrictions, and monitoring settings.

The `assignments` directory contains JSON files that specify how your initiatives should be deployed across your Azure environment. This is where you define which initiatives apply to which scopes (subscriptions, management groups, or resource groups) and how they should behave in different environments.

## Working with Assignments

The assignment configuration is the heart of how this module operates. Let's examine how it works:

```json
{
  "assignments": [
    {
      "name": "security-baseline-prod",
      "initiative": "initiatives/security/security-baseline.yml",
      "environment": "prod",
      "targets": [
        {
          "scope_type": "mg",
          "management_group_id": "mg-production"
        }
      ],
      "exemptions": [
        {
          "name": "legacy-system",
          "category": "Mitigated",
          "risk_id": "RISK-2023-001"
        }
      ]
    }
  ]
}
```

Each assignment in this configuration tells a complete story about how a policy initiative should be enforced:

The `name` field identifies this specific assignment. Choose names that clearly indicate the initiative's purpose and intended environment, making it easier to track and manage assignments over time.

The `initiative` field points to the YAML file containing your initiative definition. This creates a clear link between your assignment and the detailed policy rules it enforces.

The `environment` field enables environment-specific behavior. This same initiative might audit resources in development but enforce strict compliance in production. The environment value determines which set of parameters and effects from your initiative definition will be applied.

The `targets` section specifies where this initiative should be enforced. You can target multiple scopes with a single assignment, allowing for flexible and granular policy application. Each target must specify:
- `scope_type`: Either "mg" for management groups, "sub" for subscriptions, or "rg" for resource groups
- The appropriate identifier for that scope type (management_group_id, subscription_id, or resource_group_name)

The `exemptions` section handles special cases where policy rules need to be relaxed. Rather than weakening your overall policy stance, exemptions allow you to document and track specific exceptions. Each exemption requires:
- A descriptive `name` that identifies the exemption's purpose
- A `category` ("Waiver" or "Mitigated") indicating how the risk is being handled
- A `risk_id` for tracking and auditing purposes

## Using the Module

To use this module in your Terraform configuration:

```hcl
module "policy_initiatives" {
  source = "github.com/your-org/terraform-azurerm-policy-module"
  
  providers = {
    azurerm.target = azurerm
  }

  assignments_config_file = "${path.module}/assignments/policy-assignments.json"
  module_enabled         = true
}
```

The module requires proper provider configuration to handle cross-subscription scenarios:

```hcl
provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

provider "azurerm" {
  alias           = "target"
  features {}
  subscription_id = "11111111-1111-1111-1111-111111111111"
}
```

Through this configuration-driven approach, you can maintain consistent policy enforcement across your Azure environment while retaining the flexibility to handle environment-specific requirements and exceptions. The module handles the complexity of policy management, allowing you to focus on defining your governance requirements rather than managing individual policy resources.