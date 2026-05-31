# 02 — IAM User Access

## Problem
A team member needs EKS access. They have an IAM User. How do we give them cluster access without making them cluster-admin — and without sharing credentials?

## Concepts
- IAM User = long-term credentials (access key + secret key)
- aws-auth ConfigMap maps the user ARN → Kubernetes username + group
- That group is then bound to a ClusterRole via ClusterRoleBinding
- AWS CLI profile = named config in ~/.aws/credentials for switching identities

```
IAM User (eksadmin2)
  access key + secret key
        │  (aws configure --profile eksadmin2)
        ▼
AWS CLI Profile "eksadmin2"
        │  (aws eks update-kubeconfig --profile eksadmin2)
        ▼
kubeconfig updated
        │  (EKS checks aws-auth)
        ▼
Kubernetes username: eksadmin2
        │  (ClusterRoleBinding)
        ▼
ClusterRole: cluster-admin (for this demo)
```

## Implementation
Terraform creates:
- IAM User + access key
- IAM Policy: eks:DescribeCluster, eks:ListClusters
- aws-auth ConfigMap entry: mapUsers section

k8s-manifests:
- aws-auth ConfigMap with mapUsers entry

## Revision Notes
- IAM Users = long-term credentials. Prefer Roles (module 03) in production.
- The IAM policy needs `eks:DescribeCluster` just to run `update-kubeconfig`.
- This module = course steps 163–166 (StackSimplify).
