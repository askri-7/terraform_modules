# terraform_modules



## Repository Structure

```
.
├── documentation/          # Architecture docs
├── environment/            # Root configs per environment (calls modules)
│   ├── demo/
│   ├── dev/
│   ├── preprod/
│   ├── prod/
│   └── qa/
├── modules/                 # Reusable Terraform building blocks
│   ├── RG/                  # Resource Group module
│   ├── VM/                  # Virtual Machine module
│   └── Vnet/                # Virtual Network module
└── README.md
```