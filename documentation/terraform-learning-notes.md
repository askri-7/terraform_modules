# Terraform — My Learning Notes

> Personal notes while learning Terraform, starting with Azure (`azurerm` provider).
> Add examples, gotchas, and links as you go — this is a living document.

---

## 1. What is Terraform?

- **Terraform** is an **Infrastructure as Code (IaC)** tool by HashiCorp.
- You describe the end result of the  infrastructure you want  `.tf` files ,HashiCorp Configuration Language and Terraform figures out how to make reality match that description.
- 
- Core idea: **declarative, not imperative**. You say *what* you want, not the step-by-step *how*.



-**My notes:**
- `terraform init`: loads (pulls) all needed modules (dependencies) and providers from the Terraform Registry, and creates other dot-files I don't know about yet.
- `terraform plan`: Terraform compares the actual state of your infrastructure (tracked in `terraform.tfstate`) to the desired config in your `.tf` files, and suggests the changes in a plan.
- `terraform apply`: Terraform providers (like `azurerm`) talk to the cloud API (Azure, in this case) to apply the changes to the infrastructure.
- There's a set of files: all files ending in `.tf` are treated the same way — they're all read as if they were a single file. `.tfvars` files are used to override the variables defined in `variables.tf`. `.tfstate` files are JSON files that track the deployed infrastructure.

- Every module is a directory of `.tf` files — but a module can contain MANY resource blocks, not just one.
- It's actually each individual **resource block** (not the module itself) that tracks one real object.
- So the relationship is: module → can contain → many resources → each resource tracks → one real object.


---

## 2. Core Building Blocks

### 2.1 Providers

- A **provider** is a plugin that lets Terraform talk to a specific platform's API (Azure, AWS, GitHub, random value generation, etc.).
- Declared and pinned in a `terraform` block:

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
```

- `required_version` = minimum Terraform CLI version.
- `~> 3.0.2` = allow patch/minor updates within `3.0.x`, but not `3.1+`.
- Running `terraform init` downloads the provider plugin into a local `.terraform/` folder.

**My notes:**
- There are many providers, each specified in something like:
| Provider      | Publisher | Purpose                                   | When to use it                          |
|---------------|-----------|--------------------------------------------|------------------------------------------|
| `azurerm`     | HashiCorp | Standard Azure infra (VMs, storage, RGs)    | Default choice, almost always            |
| `azapi`       | Microsoft | Raw ARM API access, preview features        | New features not yet in `azurerm`        |
| `azuread`     | HashiCorp | Microsoft Entra ID (users, groups, apps)    | Managing identity/access resources       |
| `azuredevops` | Microsoft | Azure DevOps automation                     | Automating repos/pipelines/boards        |
| `azurestack`  | Microsoft | Azure Stack Hub (on-prem)                   | On-prem hybrid Azure deployments         |

### 2.2 Resources

- A **resource** = one real object managed by a provider (a resource group, a VM, a random string...).
- Syntax:
```hcl
resource "<RESOURCE_TYPE>" "<LOCAL_NAME>" {
  argument = value
}
```
- `RESOURCE_TYPE` (e.g. `azurerm_resource_group`) is fixed, defined by the provider.
- `LOCAL_NAME` (e.g. `rg`, `example`) is **just a label I choose** — used only inside my Terraform code to reference this resource elsewhere. It is NOT the real Azure name.
- Reference another resource's attribute: `azurerm_resource_group.rg.location`

**Key mental model:** each resource block is tracked 1-to-1 against ONE real object, via Terraform's state file. Changing the block's arguments doesn't always mean a safe "update this same object" — if the changed argument can't be modified in place (e.g. a resource group's `name`), Terraform has no choice but to DESTROY the old object and CREATE a new one to match the new config. Same address, same block, but the underlying real object gets replaced entirely.



### 2.3 Modules

- A **module** = any directory containing `.tf` files. That's the whole definition.
- **Root module** = the top-level folder you run `terraform apply` from. Every project has exactly one.
- **Child module** = a reusable module called from another module via a `module` block.

```hcl
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
  suffix  = ["test"]
}
```

- `source` = where the module code comes from (Terraform Registry, GitHub, local folder `./modules/xyz`, etc.)
- Access a child module's outputs: `module.naming.resource_group.name`

 

### 2.4 Variables & Outputs

- **Input variables** (`variables.tf`) = parameters for your config, like function arguments.
```hcl
variable "resource_group_location" {
  type    = string
  default = "eastus"
}
```
Used as `var.resource_group_location`.



### 2.5 The `random` provider (special case)

- Doesn't call any real cloud API — generates values **locally** and stores them in state.
- `random_pet` → human-readable name (`happy-giraffe`)
- `random_string` → random character string, fully configurable (length, lowercase/upper/numeric/special)
- Once created, the value is **fixed** in state — it does NOT regenerate on every `apply` unless something forces recreation.

---

---

## 4. The Core Workflow (the "chain")

```
write .tf files
     │
     ▼
terraform init      → downloads providers/modules, sets up backend
     │
     ▼
terraform plan      → dry run: shows what WILL change (create / update / destroy)
     │
     ▼
terraform apply     → executes the plan against the real provider (asks "yes" to confirm)
     │
     ▼
terraform destroy   → tears down everything Terraform is tracking (careful!)
```

### Plan symbols
| Symbol | Meaning |
|---|---|
| `+` | create |
| `~` | update in place (no destroy) |
| `-` | destroy |
| `-/+` | **replace**: destroy then create (some attribute can't be changed in-place) |

### Why replacement happens
- Some resource attributes (e.g. a resource group's `name`) have **no "update" API** in the cloud provider — the only way to change them is destroy + recreate.
- Docs mark these as *"Changing this forces a new resource to be created."*
- `# forces replacement` in plan output tells you exactly which line triggered it.

### Making replacement safer
```hcl
resource "azurerm_resource_group" "rg" {
  # ...
  lifecycle {
    create_before_destroy = true
  }
}
```
Flips the default order: **create new → then destroy old** (instead of destroy → create). Reduces downtime/risk. Only works if the new resource can coexist with the old one (e.g. different name).


## 5. Authentication (Azure specifics)

- `azurerm` provider needs credentials to call Azure's API. Common methods:
  1. **Azure CLI auth** (default, simplest for learning) — must be logged in as a **user account**, not a service principal.
     ```bash
     az login
     az account show
     ```
  2. **Service Principal auth** — explicit, used for CI/CD/automation:
     ```bash
     export ARM_CLIENT_ID="..."
     export ARM_CLIENT_SECRET="..."
     export ARM_TENANT_ID="..."
     export ARM_SUBSCRIPTION_ID="..."
     ```
- Error *"Authenticating using the Azure CLI is only supported as a User (not a Service Principal)"* → you're logged into the CLI as an SP; either switch to Option 1 or configure Option 2 explicitly.



## 6. Glossary (quick lookup)

| Term | Meaning |
|---|---|
| Provider | Plugin connecting Terraform to a platform's API |
| Resource | One real tracked object |
| Module | Folder of `.tf` files (root or child) |
| Root module | The top-level project folder |
| State | Terraform's record of what it manages |
| Plan | Dry-run diff before applying |
| Apply | Executes the plan for real |
| Replace | Destroy + recreate (attribute can't update in-place) |
| Variable | Input parameter to a config |
| Output | Exposed value after apply |
| HCL | HashiCorp Configuration Language (the `.tf` syntax) |

---
