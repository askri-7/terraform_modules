# Terraform Modules 

## 1. What is a module?

A module is just a folder with `.tf` files. Every Terraform project is already a module (the **root module**). When you call another folder with a `module` block, that's a **child module**.

Modules exist to avoid copy-pasting the same resource block over and over.

---

## 2. The problem (before)

In the original code, the same resource group logic is repeated 3 times with only the name changing:

```hcl
resource "azurerm_resource_group" "internship-web-rg-00" {
  name     = "internship-web-${module.naming_00.resource_group.name_unique}-00"
  location = var.resource_group_location
  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_resource_group" "internship-web-rg-01" {
  name     = "internship-web-${module.naming_01.resource_group.name_unique}-01"
  location = var.resource_group_location
  lifecycle {
    create_before_destroy = true
  }
}
```

Every block does the same thing → this is exactly what a module should replace.

---

## 3. Folder structure (after)

```
rg-example/
├── main.tf              # root module: calls the child module
├── variables.tf         # root input variables
├── modules/
│   └── resource-group/
│       ├── main.tf       # the resource group resource
│       ├── variables.tf  # inputs the module accepts
│       └── outputs.tf    # values the module exposes
```

---

## 4. The child module

**`modules/resource-group/variables.tf`**
```hcl
variable "name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}
```

**`modules/resource-group/main.tf`**
```hcl
resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location

  lifecycle {
    create_before_destroy = true
  }
}
```

**`modules/resource-group/outputs.tf`**
```hcl
output "name" {
  value = azurerm_resource_group.this.name
}

output "id" {
  value = azurerm_resource_group.this.id
}
```

---

## 5. The root module (calls it 3 times)

**`main.tf`**
```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

module "rg_00" {
  source   = "./modules/resource-group"
  name     = "internship-web-${module.naming.resource_group.name_unique}-00"
  location = var.resource_group_location
}

module "rg_01" {
  source   = "./modules/resource-group"
  name     = "internship-web-${module.naming.resource_group.name_unique}-01"
  location = var.resource_group_location
}

module "rg_000" {
  source   = "./modules/resource-group"
  name     = coalesce(
    "internship-web-${module.naming.resource_group.name_unique}-02",
    var.resource_group_name,
  )
  location = var.resource_group_location
}
```

---

## 6. What changed and why it's better

| Before | After |
|---|---|
| 3 near-identical `resource` blocks | 1 module, called 3 times |
| Copy-paste to add a 4th RG | Just add one more `module` block |
| Hard to reuse in another project | Drop the `resource-group` folder anywhere |
| One `naming` module per RG | One shared `naming` module, reused |


## 8. Key takeaway

> If you're writing the same resource block more than once with only a name/value changing — that's a module.

## 9. Important Notes — Why Modules Matter

1. **Modularity** — breaks infrastructure into smaller, self-contained components (e.g. a resource group, a VM, a network), making each piece easier to manage and reason about.
2. **Reusability** — write once, call many times across projects. Less duplication, more consistency.
3. **Simplified Collaboration** — teams can work on separate modules independently, then combine them into the full deployment.
4. **Versioning and Maintenance** — modules can be versioned, so consumers choose when to adopt updates instead of being forced into changes.
5. **Abstraction** — hides underlying complexity (subnets, security groups, etc.) behind simple input variables.
6. **Testing and Validation** — modules can be tested and validated in isolation before being reused elsewhere, reducing the risk of errors spreading.
7. **Documentation** — variables, outputs, and dependencies act as self-documentation, making the module's usage clear.
8. **Scalability** — new modules can be added as infrastructure grows, keeping the codebase organized instead of turning into one giant file.
9. **Security and Compliance** — best practices (IAM roles, security groups, policies) can be baked into a module once, ensuring every deployment stays consistent and compliant.
