# 01 — IAM Setup

Code lives in: `../terraform/iam.tf`

---

## What gets created

```
IAM Users (8)
  alice   → Lead DevOps
  bob     → DevOps Engineer
  charlie → Backend Lead
  dave    → Backend Dev
  eve     → Frontend Dev
  frank   → On-call SRE
  grace   → Security Auditor
  henry   → Break-glass Admin

IAM Roles (8)
  eks-cluster-admin-role      → trust: henry
  eks-devops-admin-role       → trust: alice
  eks-devops-role             → trust: bob + frank
  eks-backend-dev-admin-role  → trust: charlie
  eks-backend-dev-role        → trust: dave
  eks-frontend-dev-role       → trust: eve
  eks-readonly-role           → trust: any account user
  eks-security-role           → trust: grace

IAM Groups (6) — grant sts:AssumeRole per team
  eks-devops-admins-group  → alice
  eks-devops-group         → bob, frank
  eks-backend-admins-group → charlie
  eks-backend-devs-group   → dave
  eks-frontend-devs-group  → eve
  eks-security-group       → grace
```

---

## Why this structure

Users have zero direct EKS permissions. Permissions flow only via:

```
IAM User
  → member of IAM Group
    → Group Policy: sts:AssumeRole on one specific role
      → STS AssumeRole → temporary credentials (1 hour)
        → EKS validates role ARN → RBAC enforces access
```

Breaking the chain at any point = no access. This is why we use groups rather than attaching policies directly to users — groups make it easy to move people between roles without touching individual users.

---

## Trust policies — who can assume what

Each role's trust policy is scoped to specific user ARNs:

```hcl
# eks-devops-role trusts BOTH bob and frank
assume_role_policy = {
  Principal = { AWS = [bob.arn, frank.arn] }
  Action    = "sts:AssumeRole"
}
```

Frank (on-call SRE) assumes the same role as Bob (DevOps Engineer). Same k8s permissions. Audit trail differentiation happens via CloudTrail session name — see `00_concepts/08_kubernetes_groups_and_audit.md`.

---

## Role permissions — EKS describe only

Each role's inline policy grants only:

```json
{
  "Action": ["eks:DescribeCluster", "eks:ListClusters"],
  "Resource": "*"
}
```

This is what lets `aws eks update-kubeconfig` work on the bastion. The actual Kubernetes API permissions (what pods/logs/exec they can do) come from RBAC — NOT from IAM policies. IAM only handles authentication. RBAC handles authorization.

**Exception:** `eks-cluster-admin-role` gets `AmazonEKSClusterAdminPolicy` — the AWS managed policy that grants full Kubernetes cluster-admin. Only Henry (break-glass) gets this.

---

## Apply

```bash
cd terraform-on-aws-eks/10_01_EKS_RBAC_IAM/terraform

terraform init
terraform plan
terraform apply

# Verify
aws iam list-users --query 'Users[].UserName'
aws iam list-roles --query 'Roles[?starts_with(RoleName, `eks-`)].RoleName'
```

---

## Revision notes

- IAM = authentication only. RBAC = authorization.
- Users get no direct EKS permissions — only sts:AssumeRole via group.
- Trust policy = who can assume the role. Scope it tightly.
- `aws sts assume-role` returns 3 values: export all 3 before running kubectl.
- `AmazonEKSClusterAdminPolicy` is break-glass only — never give this to regular roles.
