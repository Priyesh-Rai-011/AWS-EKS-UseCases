#### This is the folder structure

```
PS C:\Users\KIIT\Desktop\Everything\AWSEKS\terraform-on-aws-eks\eks-basic\eks-public-nodegroup> tree /F
Folder PATH listing for volume Windows-SSD
Volume serial number is 9841-2D5E
C:.
│   .terraform.lock.hcl
│   backend.tf
│   locals.tf
│   main.tf
│   output.tf
│   variable.tf
│   
│   
│   terraform.tfvars
│   
└───modules
    ├───bastion
    │       main.tf
    │       outputs.tf
    │       variables.tf
    │
    ├───eks
    │       iam.tf
    │       main.tf
    │       outputs.tf
    │       variables.tf
    │
    └───vpc
            main.tf
            outputs.tf
            variables.tf

            
│
├───.terraform
│   │   terraform.tfstate
│   │
│   ├───modules
│   │       modules.json
│   │
│   └───providers
│       └───registry.terraform.io
│           └───hashicorp
│               └───aws
│                   └───5.100.0
│                       └───windows_amd64
│                               LICENSE.txt
│                               terraform-provider-aws_v5.100.0_x5.exe
│
```