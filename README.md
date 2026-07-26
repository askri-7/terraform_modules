# terraform_modules



## Repository Structure

```
.
├── documentation/          # Architecture docs
├── environment/            # Root configs per environment (calls modules)
│   ├── dev/
    ├── qa/
    ├── demo/
│   ├── preprod/
│   ├── prod/
│   
├── modules/                 # Reusable Terraform building blocks
│   ├── RG/                  # Resource Group module
    ├ workflow_identity      # the github action identity         
│   ├── VM/                  # Virtual Machine module
    ├──  public_ip/          # public ip generator
│   └── Vnet/                # Virtual Network module
└── README.md
```