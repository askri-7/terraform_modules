# Terraform State File

Terraform keeps track of everything it manages in a file called `terraform.tfstate`. It's how Terraform knows what already exists, so it can calculate what to add, change, or destroy.

---

## 1. Why the state file matters

- **Resource tracking** — knows every resource it created and its current attributes.
- **Plan calculation** — compares your code vs. the state to figure out the diff.
- **Locking** — prevents two people from running `apply` at the same time.

---

## 2. The problem with keeping it local (or in Git)

- If it's on your laptop only, no one else can run Terraform safely.
- If you commit it to Git, secrets stored in the state (passwords, keys) get exposed to everyone with repo access.
- No locking → two people applying at once can corrupt the state.

**Fix:** store the state remotely, in a shared, locked location.

---

## 3. The fix — Azure Blob Storage as a remote backend/S3

Azure Storage handles locking automatically (via blob lease) — no extra locking table needed.

### Step 1 — Create the storage account (Azure CLI)/(Azure portal)


### Step 2 — Point Terraform to it (backend.tf)

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-name"
    storage_account_name = "storage-name"
    container_name       = "tfstate"
    key                  = "path/to/terraform.tfstate"
  }
}
```

That's it no separate lock table like DynamoDB. Unlike S3 ,  Azure Blob's lease mechanism handles locking on its own.

---

## 4. Full example — backend + a simple resource group

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

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-name"
    storage_account_name = "storage-name"
    container_name       = "tfstate"
    key                  = "path/to/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "internship-web-rg"
  location = "eastus"

  lifecycle {
    create_before_destroy = true
  }
}
```

---



## 5. Important Notes

1. **Never commit `terraform.tfstate` to Git** — it can contain secrets in plain text.
2. **Remote backend = shared state** — the whole team works off the same source of truth.
3. **Azure Blob locking is automatic** — no DynamoDB-style setup needed, unlike AWS S3.
4. **Enable `encrypt`** on the storage account so the state is protected at rest.
5. **One state file per environment** — use a different `key` (e.g. `dev.tfstate`, `prod.tfstate`) to keep environments isolated.