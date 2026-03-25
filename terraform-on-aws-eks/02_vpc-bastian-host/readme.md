#### Well this will be the folder structure

```
vpc-bastian-host/
├── modules/
│   ├── vpc/
│   └── bastion/
├── main.tf        ← root module that wires everything together
├── variables.tf
├── outputs.tf
├── locals.tf
├── backend.tf
└── terraform.tfvars
```


#### Well this will be the conceptual flow

```
terraform.tfvars
      ↓
root variables.tf        (declares what inputs exist)
      ↓
root main.tf             (passes values INTO modules)
      ↓
   ┌──────────────────┐        ┌─────────────────────┐
   │  module "vpc"    │  ───→  │  module "bastion"   │
   │                  │        │                     │
   │  Creates VPC,    │        │  Needs vpc_id and   │
   │  subnets, NAT,   │        │  subnet_id          │
   │  route tables    │        │                     │
   │                  │        │  Gets them from:    │
   │  outputs.tf      │        │  module.vpc.vpc_id  │
   │  ↳ vpc_id        │ ──────→│  module.vpc.        │
   │  ↳ public_subnet │        │    public_subnet_ids│
   └──────────────────┘        └─────────────────────┘
```
### We are not choosing the ssh
#### we are having the bastian host on the public subnet with ssm login - so no ssh and no cidr
#### we are using same security group

```
SSH:   You → port 22 (open to internet) → Bastion EC2
SSM:   You → AWS Console/CLI → SSM Agent (inside EC2) → Bastion EC2
                                ↑
                         port 443 outbound only
                         (EC2 calls OUT to AWS, nothing comes IN)
```