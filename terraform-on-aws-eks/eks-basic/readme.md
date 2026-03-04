#### Things that will be in the configuration

```
VPC
    - subnets (public / private / database)
    - route tables
    - NAT gateway + Elastic IP
    - Internet Gateway
Bastion Host
    - Bastion Host EC2 instance
    - Bastion host - security group
    - Bastion host - elactic IP
EKS Cluster
    - EKS cluster IAM role
    - EKS cluster security group
    - EKs cluster Network Interfaces (ENI)
    - EKS cluster
EKS Node Group
    - ESK node group IAM role
    - EKS node group security group
    - EKS node group network interface
    - Eks worker node EC2 instace
```