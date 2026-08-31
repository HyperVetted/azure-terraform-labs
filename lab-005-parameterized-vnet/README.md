# LAB-005 — Parameterized Azure Virtual Network

This lab builds a small Azure network with Terraform using an existing Azure Resource Group.

The goal was to move beyond hardcoded values and build a configuration that is easier to read, reuse, and understand. The lab focuses on **variables, locals, data sources, resource references, outputs, Terraform state, and idempotency**.

## What the Lab Builds

- 1 Azure Virtual Network
- 3 Azure subnets
- Common tags on the VNet
- Terraform outputs for useful resource values

The Resource Group is **not created by this configuration**. Terraform reads an existing Resource Group with a data source and uses its name and location when creating the network.

---

## Architecture

```text
Existing Azure Resource Group
        │
        │  read with a data source
        ▼
lab005-dev-vnet
10.80.0.0/16
        │
        ├── lab005-dev-web-snet
        │   10.80.1.0/24
        │
        ├── lab005-dev-app-snet
        │   10.80.2.0/24
        │
        └── lab005-dev-mgmt-snet
            10.80.3.0/24
```

The VNet uses the Azure location of the existing Resource Group.

---

## Concepts Practiced

This lab intentionally stays with core Terraform concepts. It does not use modules, `count`, `for_each`, or a remote backend.

The main concepts practiced were:

- input variables
- variable types and defaults
- `terraform.tfvars`
- locals for derived values
- Azure data sources
- resource references
- implicit dependencies
- Terraform outputs
- Terraform state
- plan/apply workflow
- idempotency

---

## Repository Structure

```text
lab-005-parameterized-vnet/
├── providers.tf
├── variables.tf
├── locals.tf
├── paramvnetlab.tf
├── outputs.tf
├── terraform.tfvars.example
└── README.md
```

| File | Purpose |
|---|---|
| `providers.tf` | Declares and configures the AzureRM provider |
| `variables.tf` | Defines the configuration inputs |
| `locals.tf` | Builds standardized names and common tags |
| `paramvnetlab.tf` | Reads the existing Resource Group and creates the VNet/subnets |
| `outputs.tf` | Exposes useful values after deployment |
| `terraform.tfvars.example` | Example values for the lab |
| `README.md` | Lab documentation |

> Terraform reads all `.tf` files in the working directory. `paramvnetlab.tf` could also be named `main.tf`; the filename does not change Terraform behavior.

---

## Prerequisites

Before running the lab:

- Install Terraform
- Install Azure CLI
- Have access to an Azure subscription
- Have an existing Azure Resource Group
- Authenticate to Azure

Sign in:

```powershell
az login
```

Verify Terraform:

```powershell
terraform version
```

---

## Provider Configuration

The lab uses the HashiCorp AzureRM provider:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

`required_providers` tells Terraform which provider plugin is required.

The `provider "azurerm"` block configures the Azure provider used by the resources in this lab.

---

## Input Variables

The configuration accepts these inputs:

| Variable | Type | Purpose |
|---|---|---|
| `rg_name` | `string` | Existing Resource Group name |
| `project` | `string` | Project name used in resource naming |
| `environment` | `string` | Environment name; defaults to `dev` |
| `vnet_address_space` | `list(string)` | VNet address space |
| `web_cidr` | `list(string)` | Web subnet CIDR |
| `app_cidr` | `list(string)` | App subnet CIDR |
| `mgmt_cidr` | `list(string)` | Management subnet CIDR |

The environment variable has a default:

```hcl
variable "environment" {
  type    = string
  default = "dev"
}
```

If `environment` is not supplied elsewhere, Terraform uses `dev`.

---

## Configure the Lab

Copy the included example file:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Then update `rg_name` so it matches an existing Resource Group in your Azure subscription.

Example:

```hcl
rg_name = "your-existing-resource-group"

project = "lab005"

vnet_address_space = ["10.80.0.0/16"]

app_cidr = ["10.80.2.0/24"]
web_cidr = ["10.80.1.0/24"]
mgmt_cidr = ["10.80.3.0/24"]
```

Because `environment` is not specified here, the default value `dev` is used.

That produces names such as:

```text
lab005-dev-vnet
lab005-dev-web-snet
lab005-dev-app-snet
lab005-dev-mgmt-snet
```

---

## Locals

Locals are used for values that are derived inside the configuration.

Example:

```hcl
locals {
  vnet_name = "${var.project}-${var.environment}-vnet"
}
```

With:

```text
project     = lab005
environment = dev
```

Terraform evaluates that local as:

```text
lab005-dev-vnet
```

The same approach is used for the subnet names.

The lab also uses a local map for common tags:

```hcl
common_tags = {
  environment = var.environment
  managed_by  = "terraform"
}
```

This avoids repeating the same tag values in multiple places.

---

## Existing Resource Group Data Source

The Resource Group already exists, so the configuration reads it with a data source:

```hcl
data "azurerm_resource_group" "existing" {
  name = var.rg_name
}
```

This does **not** create the Resource Group.

It tells Terraform to look up the existing Resource Group and make attributes such as these available:

```hcl
data.azurerm_resource_group.existing.name
data.azurerm_resource_group.existing.location
```

Those values can then be reused by the VNet and subnet resources.

---

## Virtual Network

The VNet combines several value sources:

```hcl
resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  address_space       = var.vnet_address_space
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  tags                = local.common_tags
}
```

Value-source breakdown:

```text
name                → local
address_space       → variable
location            → data-source attribute
resource_group_name → data-source attribute
tags                → local
```

This is one of the main lessons of the lab: different resource arguments can get their values from different Terraform sources.

---

## Subnets

Three subnets are created:

```text
azurerm_subnet.web
azurerm_subnet.app
azurerm_subnet.mgmt
```

Each subnet gets:

- its name from a local
- its CIDR from a variable
- its Resource Group name from the data source
- its VNet name from the managed VNet

Example:

```hcl
resource "azurerm_subnet" "web" {
  name                 = local.web_snet_name
  resource_group_name  = data.azurerm_resource_group.existing.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.web_cidr
}
```

The reference:

```hcl
azurerm_virtual_network.main.name
```

also gives Terraform dependency information.

Terraform therefore knows that the VNet must exist before the subnet can be created.

No explicit `depends_on` is required here.

---

## Outputs

The configuration exposes:

```text
vnet_name
vnet_id
web_snet_id
app_snet_id
mgmt_snet_id
existing_rg_location
```

Example:

```hcl
output "vnet_id" {
  value = azurerm_virtual_network.main.id
}
```

View all outputs:

```powershell
terraform output
```

Read one value directly:

```powershell
terraform output -raw vnet_id
```

Outputs are useful for humans, scripts, and later automation because they provide a clear way to expose selected Terraform values.

---

# Deployment

## 1. Initialize

```powershell
terraform init
```

This initializes the working directory and installs the required provider.

## 2. Format

```powershell
terraform fmt
```

## 3. Validate

```powershell
terraform validate
```

Expected result:

```text
Success! The configuration is valid.
```

## 4. Review the Plan

```powershell
terraform plan
```

For a clean first deployment, the expected infrastructure summary is:

```text
Plan: 4 to add, 0 to change, 0 to destroy.
```

The four managed resources are:

```text
azurerm_virtual_network.main
azurerm_subnet.web
azurerm_subnet.app
azurerm_subnet.mgmt
```

The existing Resource Group is read through a data source, so it is not included as a resource being created.

## 5. Apply

```powershell
terraform apply
```

Review the plan and confirm the deployment.

The completed lab produced:

```text
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

---

## Deployment Result

| Resource | Name | CIDR |
|---|---|---|
| VNet | `lab005-dev-vnet` | `10.80.0.0/16` |
| Web subnet | `lab005-dev-web-snet` | `10.80.1.0/24` |
| App subnet | `lab005-dev-app-snet` | `10.80.2.0/24` |
| Management subnet | `lab005-dev-mgmt-snet` | `10.80.3.0/24` |

---

## Inspect Terraform State

After deployment:

```powershell
terraform state list
```

The lab state contains:

```text
data.azurerm_resource_group.existing
azurerm_subnet.app
azurerm_subnet.mgmt
azurerm_subnet.web
azurerm_virtual_network.main
```

A key lesson from this lab is:

```text
Resource exists in Azure
≠
resource is automatically managed by this Terraform state
```

Terraform state tracks the objects associated with Terraform addresses in the current working directory/state.

An unrelated Azure resource can exist in the same Resource Group without being part of this Terraform configuration.

---

## Working Directory and State Lesson

During the lab, the first plan was accidentally run from an older Terraform working directory.

That older state already had a VNet bound to:

```text
azurerm_virtual_network.main
```

The new LAB-005 configuration reused that same Terraform address. Terraform therefore treated the new configuration as a change to the previously tracked VNet and proposed replacing it.

The fix was to use a clean LAB-005 working directory with its own state.

For a new greenfield lab, do not copy old Terraform working-state files into the new directory:

```text
terraform.tfstate
terraform.tfstate.backup
.terraform/
```

This reinforced the difference between:

```text
what exists in Azure
```

and:

```text
what a specific Terraform state tracks
```

---

## Verify Idempotency

After the successful deployment:

```powershell
terraform plan
```

With no configuration or infrastructure changes, Terraform returned:

```text
No changes. Your infrastructure matches the configuration.
```

That confirms the deployed infrastructure matches the desired Terraform configuration.

---

## Cleanup

When the lab is no longer needed:

```powershell
terraform destroy
```

Always review the destroy plan before confirming it.

The Resource Group is only a data source in this lab, so the configuration is intended to destroy the VNet and subnets it manages, not the existing Resource Group.

---

## Security Notes

Do not commit:

- Azure credentials
- client secrets
- access tokens
- private keys
- sensitive Terraform state
- other secrets

This lab authenticates to Azure outside the Terraform configuration instead of hardcoding credentials into `.tf` files.

For a public GitHub repository, `terraform.tfvars.example` documents the expected inputs while allowing your real `terraform.tfvars` to remain local.

---

## Key Takeaways

```text
variable
→ external/configuration input

local
→ internally derived or reusable value

data source
→ reads existing infrastructure

resource
→ infrastructure Terraform manages

resource reference
→ reads an attribute and can create a dependency

output
→ exposes a selected Terraform value

state
→ records Terraform's bindings to real infrastructure
```

The biggest practical takeaway was that Terraform is not simply managing everything it finds inside an Azure Resource Group.

Terraform uses its configuration, state, provider reads, and resource bindings to determine what it manages and what actions are required.

---

## Final Lab Result

```text
LAB-005: COMPLETE

Initial clean plan:
4 to add
0 to change
0 to destroy

Apply:
4 added
0 changed
0 destroyed

Final plan:
No changes. Your infrastructure matches the configuration.
```
