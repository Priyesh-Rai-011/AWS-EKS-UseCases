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


## EKS Addons & Their IAM Dependency
```
┌──────────────────────────────────────────────────────────┐
│ Addon             │ Needs IAM?  │ Role Used              │
├──────────────────────────────────────────────────────────┤
│ vpc-cni           │     Yes     │ nodegrp_role           │
│                   │             │ (AmazonEKS_CNI_Policy) │
├──────────────────────────────────────────────────────────┤
│ coredns           │ No          │ Uses node role         │
├──────────────────────────────────────────────────────────┤
│ kube-proxy        │ No          │ Uses node role         │
├──────────────────────────────────────────────────────────┤
│ aws-ebs-csi-driver│     Yes     │ ebs_csi_driver_role    │
├──────────────────────────────────────────────────────────┤
│ metrics-server    │ No          │ Uses node role         │
└──────────────────────────────────────────────────────────┘
```
---

###  How things flow

```
==========================================================================
                    COMPLETE EKS PRODUCTION ARCHITECTURE
==========================================================================
 
YOUR AWS ACCOUNT
|
+-- YOUR VPC
|   |
|   +-- Public Subnets
|   |     ALB / NLB (created by EKS using ekscluster_role)
|   |
|   +-- Private Subnets
|         |
|         +-- ENI (PrivateLink)  <-- created by EKS using ekscluster_role
|         |   IP: 10.0.11.200        This is the bridge to the control plane
|         |
|         +-- EC2 Worker Node ip-10-0-11-50
|               Role: nodegrp_role
|               |
|               +-- P1: AmazonEKSWorkerNodePolicy    --> joins the cluster
|               +-- P2: AmazonEKS_CNI_Policy         --> gives pods VPC IPs
|               +-- P3: AmazonEC2ContainerRegistryReadOnly  --> pulls images from ECR
|               +-- P4: AmazonSSMManagedInstanceCore --> SSM shell access, no port 22
|               +-- P5: AmazonSESFullAccess          --> app sends emails
|               +-- P6: AmazonS3FullAccess           --> app reads/writes S3
|               +-- P7: SecretsManagerReadWrite      --> app fetches secrets
|
|
+============================================================================================
|
+-- AWS MANAGED VPC  ( invisible - compleately managed by the AWS )
|   |
|   +-- EKS Control Plane
|         Role: ekscluster_role
|         |
|         +-- P1: AmazonEKSClusterPolicy          --> manages ENIs, LBs, SGs
|         +-- P2: AmazonEKSVPCResourceController  --> Security Groups per Pod
|         |
|         +-- Internal NLB --> EKS API Server --> etcd, Scheduler, Controllers
|
+-- EBS VOLUMES  (persistent storage)
     |
     +-- EBS CSI Driver Addon
           Role: ebs_csi_driver_role
           +-- P1: AmazonEBSCSIDriverPolicy --> CreateVolume, AttachVolume
 
  PVC requested --> EBS CSI Driver --> CreateVolume --> AttachVolume --> Pod mounts /data

```