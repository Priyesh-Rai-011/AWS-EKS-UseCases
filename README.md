# AWS-EKS-UseCases
Kalyan Reddy Daida course


Awsome commands I come accross


```
# Define the source and destination base paths
$sourceBase = "C:\Users\KIIT\Desktop\Everything\AWSEKS\terraform-on-aws-eks\vpc-bastian-host\modules"
$destBase = "C:\Users\KIIT\Desktop\Everything\AWSEKS\terraform-on-aws-eks\eks-basic\eks-private-nodegroup\modules"

# Copy VPC content (Mapping output.tf to outputs.tf)
Get-Content "$sourceBase\vpc\main.tf" | Set-Content "$destBase\vpc\main.tf"
Get-Content "$sourceBase\vpc\variables.tf" | Set-Content "$destBase\vpc\variables.tf"
Get-Content "$sourceBase\vpc\output.tf" | Set-Content "$destBase\vpc\outputs.tf"

# Copy Bastion content (Mapping bastian folder to bastion folder and output.tf to outputs.tf)
Get-Content "$sourceBase\bastian\main.tf" | Set-Content "$destBase\bastion\main.tf"
Get-Content "$sourceBase\bastian\variables.tf" | Set-Content "$destBase\bastion\variables.tf"
Get-Content "$sourceBase\bastian\output.tf" | Set-Content "$destBase\bastion\outputs.tf"
```