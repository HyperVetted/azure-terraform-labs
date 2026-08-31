# LAB-005 — Parameterized Azure Virtual Network with Terraform

This lab builds a small Azure network with Terraform while practicing **input variables, locals, data sources, resource references, outputs, state, and idempotency**.

The configuration uses an **existing Azure Resource Group**, then creates:

- 1 Azure Virtual Network
- 3 subnets
- Common resource tags
- Useful Terraform outputs

The lab was built as a greenfield Terraform deployment rather than as a refactor of an existing configuration.

---

## Architecture

```text
Existing Azure Resource Group
        │
        │  data.azurerm_resource_group.existing
        │
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

The VNet is created in the same Azure region as the existing Resource Group.

---

## What This Lab Practices

This lab focuses on core Terraform skills without introducing more advanced features such as modules, `count`, or `for_each`.

### Input variables

Values that can change between deployments are defined as variables, including:

- Resource Group name
- Project name
- Environment
- VNet address space
- Subnet CIDRs

### Locals

Locals are used to build consistent names and tags from the input variables.

For example:

```hcl
vnet_name = "${var.project}-${var.environment}-vnet"
```

With the current values, this becomes:

```text
lab005-dev-vnet
```

### Data source

The Resource Group already exists, so Terraform reads it with a data source instead of creating a new one.

```hcl
data "azurerm_resource_group" "existing" {
  name = var.rg_name
}
```

This allows the configuration to reuse values such as the Resource Group name and location.

### Resource references

Each subnet references the VNet created by Terraform:

```hcl
virtual_network_name = azurerm_virtual_network.main.name
```

This also gives Terraform the dependency information it needs to create the VNet before the subnets.

### Outputs

Outputs expose useful values after the deployment, including:

- VNet name
- VNet ID
- Web subnet ID
- App subnet ID
- Management subnet ID
- Existing Resource Group location

These values can be viewed manually with `terraform output` or consumed by later automation.

---

## Repository Structure

```text
.
├── providers.tf
├── variables.tf
├── locals.tf
├── paramvnetlab.tf
├── outputs.tf
└── terraform.tfvars
```

### File purpose

| File | Purpose |
|---|---|
| `providers.tf` | Configures the AzureRM provider |
| `variables.tf` | Declares the lab's input variables |
| `locals.tf` | Builds resource names and common tags |
| `paramvnetlab.tf` | Reads the existing RG and creates the VNet and subnets |
| `outputs.tf` | Exposes useful values after deployment |
| `terraform.tfvars` | Supplies the lab-specific input values |

---

## Prerequisites

Before running the lab, you need:

- Terraform installed
- Azure CLI installed
- Access to an Azure subscription
- An existing Azure Resource Group
- Azure CLI authentication completed

Authenticate to Azure:

```powershell
az login
```

Confirm that Terraform is installed:

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

---

## Input Variables

The lab declares the following variables:

| Variable | Type | Description |
|---|---|---|
| `rg_name` | `string` | Existing Azure Resource Group name |
| `project` | `string` | Project name used in resource naming |
| `environment` | `string` | Environment name; defaults to `dev` |
| `vnet_address_space` | `list(string)` | VNet address space |
| `web_cidr` | `list(string)` | Web subnet CIDR |
| `app_cidr` | `list(string)` | App subnet CIDR |
| `mgmt_cidr` | `list(string)` | Management subnet CIDR |

The current lab values are:

```hcl
rg_name = "tfs-r0-ue2-trn"

project = "lab005"

vnet_address_space = ["10.80.0.0/16"]

app_cidr = ["10.80.2.0/24"]

web_cidr = ["10.80.1.0/24"]

mgmt_cidr = ["10.80.3.0/24"]
```

`environment` is intentionally not set in `terraform.tfvars`, so Terraform uses its default value:

```hcl
default = "dev"
```

> Replace `rg_name` with the name of an existing Resource Group if you run this configuration in a different Azure environment.

---

## Naming and Tags

Resource names are derived in `locals.tf`.

The current values produce:

| Resource | Name |
|---|---|
| VNet | `lab005-dev-vnet` |
| Web subnet | `lab005-dev-web-snet` |
| App subnet | `lab005-dev-app-snet` |
| Management subnet | `lab005-dev-mgmt-snet` |

The VNet also receives these common tags:

```text
environment = dev
managed_by  = terraform
```

---

## Resources Created

### Virtual Network

The VNet receives its values from variables, locals, and the existing Resource Group data source.

```hcl
resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  address_space       = var.vnet_address_space
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  tags                = local.common_tags
}
```

### Subnets

Three subnet resources are created:

```text
azurerm_subnet.web
azurerm_subnet.app
azurerm_subnet.mgmt
```

Each subnet gets its CIDR from a variable and references the VNet created by Terraform.

---

## Deploy the Lab

### 1. Initialize Terraform

```powershell
terraform init
```

This initializes the working directory and installs the required AzureRM provider.

### 2. Format the configuration

```powershell
terraform fmt
```

### 3. Validate the configuration

```powershell
terraform validate
```

A valid configuration should return:

```text
Success! The configuration is valid.
```

### 4. Review the execution plan

```powershell
terraform plan
```

For a new deployment with clean Terraform state, the expected infrastructure plan is:

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

The existing Resource Group is only read through a data source, so Terraform does not create or replace it.

### 5. Apply the configuration

```powershell
terraform apply
```

Review the plan and confirm the deployment when prompted.

The completed lab deployment produced:

```text
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

---

## View the Outputs

Run:

```powershell
terraform output
```

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

```text
vnet_name            = "lab005-dev-vnet"
existing_rg_location = "eastus2"
```

Resource IDs are generated by Azure and are known after the resources are created.

For automation, an individual value can also be read directly:

```powershell
terraform output -raw vnet_id
```

---

## Inspect Terraform State

Run:

```powershell
terraform state list
```

After a successful deployment, this lab tracks:

```text
data.azurerm_resource_group.existing
azurerm_subnet.app
azurerm_subnet.mgmt
azurerm_subnet.web
azurerm_virtual_network.main
```

An important takeaway from this lab is that **an Azure resource does not automatically become Terraform-managed just because it exists in the same Resource Group**.

Terraform state tracks the objects that are associated with Terraform addresses in this working directory.

---

## Verify Idempotency

After the deployment, run another plan:

```powershell
terraform plan
```

With no configuration or infrastructure changes, Terraform should report:

```text
No changes. Your infrastructure matches the configuration.
```

This confirms that the deployed Azure resources match Terraform's desired configuration.

---

## Clean Up

When the lab resources are no longer needed:

```powershell
terraform destroy
```

Review the destroy plan before confirming it.

The Resource Group itself is a **data source**, not a managed resource in this configuration, so this lab is intended to destroy only the Terraform-managed VNet and subnets.

---

## Key Takeaways

- **Variables** provide configurable input values.
- **Locals** build reusable or derived values such as names and tags.
- **Data sources** read information about infrastructure that already exists.
- **Resource references** connect resources and give Terraform dependency information.
- **Outputs** expose useful values for people or automation.
- **Terraform state** tracks Terraform's relationship with managed infrastructure.
- A final no-change plan confirms that the deployed infrastructure matches the configuration.

---

## Security Note

Do not commit Azure credentials, client secrets, access tokens, subscription secrets, or other sensitive values to GitHub.

This configuration does not require credentials to be written directly into the Terraform files. Authentication can be handled through the Azure CLI.

---

## Lab Result

```text
Deployment: SUCCESS

Resources added:   4
Resources changed: 0
Resources destroyed: 0

Final verification:
No changes. Your infrastructure matches the configuration.
```
