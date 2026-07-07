# What This Config Creates

## Providers & module calls
- `azurerm` provider configured (v3.0.2, requires Terraform ≥1.1.0).
- **Three separate `naming` module instances**: `naming00`, `naming_00`, `naming_01`.
  Since each is a separate module call, each generates its **own independent random suffix** (this fixes the "same random name every time" issue from before).

## Resources created (3 Azure Resource Groups)

| Terraform address | Name source | Resulting name (example) |
|---|---|---|
| `azurerm_resource_group.internship-web-rg-00` | `module.naming_00` | `internship-web-<random_00>-00` |
| `azurerm_resource_group.internship-web-rg-01` | `module.naming_01` | `internship-web-<random_01>-01` |
| `azurerm_resource_group.internship-web-rg-000` | `local.resource_group_name` | `internship-web-<random_00>-02` |

All three use `create_before_destroy = true`, so if any of them are ever renamed, the new one is created before the old one is destroyed.

## The `locals` block
```hcl
locals {
  resource_group_name = coalesce("internship-web-${module.naming00.resource_group.name_unique}-02", var.resource_group_name)
}
```
- Always evaluates to the first argument (`internship-web-<random>-02`), since it's a non-empty string.
- `var.resource_group_name` (the fixed `"internship-web-rg"` default) is **never actually used** — it's only a fallback for if the first argument were empty/null, which it never is.

## Variables
- `resource_group_name` — declared but currently has no real effect (see above).
- `resource_group_location` — used by all three resource groups, defaults to `"westus2"`.

## Net result of `terraform apply`
Three distinct Azure Resource Groups get created in `westus2`, each with a different random suffix, all named following the `internship-web-<random>-NN` pattern.

## Things to double check
- `naming00` (no underscore) is only used inside `locals` — confirm that's intentional and not a typo of `naming_00`.
- The `resource_group_name` variable is dead weight right now unless you rework the `coalesce()` order (fixed value first, random fallback second).
