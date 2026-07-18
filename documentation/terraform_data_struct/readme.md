# Terraform Data Structures & Loops 

A reference for Terraform's type system, how the types interact/nest, and when you actually need a loop (`for`, `for_each`, `count`, `dynamic`) — examples using the `azurerm` provider.

---

## 1. Primitive Types

The atoms. Everything else is built from these.

| Type | Example | Notes |
|---|---|---|
| `string` | `"East US"` | Text, always quoted |
| `number` | `2`, `3.14` | Ints and floats, no separate int type |
| `bool` | `true`, `false` | Used in conditionals, `count`, feature flags |

```hcl
variable "location" {
  type    = string
  default = "East US"
}
```

No loop needed. These are single values — a loop has nothing to iterate over.

---

## 2. Collection Types

Groups of values, **all the same type**.

### `list` — ordered, indexable, duplicates allowed
```hcl
variable "zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}
# access: var.zones[0]
```

### `set` — unordered, unique values only
```hcl
variable "allowed_ports" {
  type    = set(number)
  default = [22, 80, 443]
}
```

### `map` — key/value pairs, all values same type
```hcl
variable "vm_sizes" {
  type = map(string)
  default = {
    dev  = "Standard_B2s"
    prod = "Standard_D4s_v5"
  }
}
# access: var.vm_sizes["dev"]
```

**Loop trigger:** as soon as you want to *do something with every element* — create a resource per item, transform every value, build a new list/map from an existing one — you need a `for` expression or a `for_each`. Simple indexed access (`var.zones[0]`) does not.

---

## 3. Structural Types

Groups of values that can **mix types**, fixed shape.

### `object` — named attributes, each with its own type
```hcl
variable "vm" {
  type = object({
    name = string
    size = string
    tags = list(string)
  })
  default = {
    name = "vm-web-1"
    size = "Standard_B2s"
    tags = ["prod", "web"]
  }
}
```

### `tuple` — ordered, positional, each position its own type
```hcl
variable "record" {
  type    = tuple([string, number, bool])
  default = ["app", 8080, true]
}
```

**Loop trigger:** rarely, on their own — objects/tuples usually represent *one thing*. They start needing loops when you have a **collection of objects** (a list of objects, a map of objects), which is extremely common in real configs.

---

## 4. How They Interact (Nesting)

Real-world Terraform is almost always a **collection of structural types**. In Azure this shows up constantly for things like subnets inside a vnet, or NICs per VM.

```hcl
variable "subnets" {
  type = list(object({
    name             = string
    address_prefixes = list(string)
  }))
  default = [
    { name = "snet-web", address_prefixes = ["10.0.1.0/24"] },
    { name = "snet-app", address_prefixes = ["10.0.2.0/24"] },
  ]
}
```

or a **map of objects** (often nicer than a list because each entry gets a stable key):

```hcl
variable "subnets" {
  type = map(object({
    address_prefixes = list(string)
  }))
  default = {
    web = { address_prefixes = ["10.0.1.0/24"] }
    app = { address_prefixes = ["10.0.2.0/24"] }
  }
}
```

This is the shape that almost always needs a loop, because you want **one resource instance per entry**.

---

## 5. Do You Need a Loop? Decision Guide

| Situation | Need a loop? | Tool |
|---|---|---|
| Single static value (`var.location`) | No | Direct reference |
| Fixed number of near-identical resources, no per-item config | Maybe | `count` |
| One resource per item in a list/map, each with different attributes | **Yes** | `for_each` |
| Repeating a nested *block* inside one resource (e.g. multiple NIC `ip_configuration` blocks, or NSG `security_rule` blocks) | **Yes** | `dynamic` block |
| Transforming a collection into another collection/value (no resources involved) | **Yes** | `for` expression |

### `count` — simplest, index-based
Good for N identical (or index-differentiated) resources.
```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  count               = 3
  name                = "vm-${count.index}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  # ...
}
```
Weakness: if you remove an item from the middle of the source list, Terraform shifts indices and may destroy/recreate resources that didn't actually change — risky for stateful things like VMs and disks.

### `for_each` — key-based, stable
Preferred when items differ from each other, or when set/map ordering matters more than position.
```hcl
resource "azurerm_subnet" "this" {
  for_each             = var.subnets            # map(object({...}))
  name                 = each.key
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes
}
```
If your source is a `list`, convert it to a map first (e.g. `{ for s in var.subnets : s.name => s }`) so each item has a stable key — this avoids the `count` reindexing problem, which matters a lot for Azure resources with long provisioning times (VMs, SQL, AKS).

### `for` expression — transform, don't create resources
Used inside a value (a `locals` block, a variable default, an argument) to reshape data.
```hcl
locals {
  subnet_ids = [for s in azurerm_subnet.this : s.id]

  subnet_prefix_map = { for k, s in var.subnets : k => s.address_prefixes[0] }

  prod_only = [for s in var.subnets : s if s.env == "prod"]
}
```

### `dynamic` block — repeat a nested block inside a single resource
Used when a resource has a repeatable sub-block (like `security_rule` in an NSG, or `ip_configuration` in a NIC) and the number of repetitions is variable.
```hcl
resource "azurerm_network_security_group" "this" {
  name                = "nsg-app"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  dynamic "security_rule" {
    for_each = var.allowed_ports
    content {
      name                       = "allow-${security_rule.value}"
      priority                   = 100 + security_rule.value
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = tostring(security_rule.value)
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}
```

---

## 6. Quick Rules of Thumb

- **Single value → no loop.**
- **List/set/map of primitives you just need to reference as a whole → no loop** (pass the whole collection to an argument that accepts a list, e.g. `zones = var.zones`).
- **One resource per item → `for_each`** (prefer over `count` unless items are truly identical/order-based — especially important in Azure where recreating a VM/disk/database is expensive and slow).
- **Reshaping data, not creating resources → `for` expression.**
- **Repeating a block inside one resource → `dynamic`** (common Azure cases: `security_rule` in NSGs, `ip_configuration` in NICs, `data_disk` blocks on VMs).
- **Source is a list but you want `for_each` → convert list to map with a `for` expression first**, so each item has a stable, meaningful key.

---

## 7. Small Full Example — Resource Group + Subnets via `for_each`

```hcl
resource "azurerm_resource_group" "this" {
  name     = "rg-network"
  location = var.location
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-main"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  for_each             = var.subnets
  name                 = each.key
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes
}
```

With `var.subnets` as the map-of-objects shown in Section 4, this creates one `azurerm_subnet` per entry, each named after its map key (`web`, `app`) — no `count`, no index math, and adding/removing a subnet later doesn't reshuffle the others.
