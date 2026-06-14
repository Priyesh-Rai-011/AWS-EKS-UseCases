# End-to-End EKS Access Flow

## Problem
Too many moving parts to hold in your head at once. This document is the single diagram that connects everything.

## The Complete Flow

```
Developer runs: kubectl get pods -n dev
                        │
                        ▼
          ┌─────────────────────────┐
          │   AWS STS               │
          │   Validates IAM token   │
          └────────────┬────────────┘
                        │  token valid
                        ▼
          ┌─────────────────────────┐
          │   EKS API Server        │
          │   Checks aws-auth /     │
          │   Access Entry          │
          └────────────┬────────────┘
                        │  maps to k8s group "eks-developers"
                        ▼
          ┌─────────────────────────┐
          │   Kubernetes RBAC       │
          │   RoleBinding:          │
          │   eks-developers →      │
          │   Role dev-readonly     │
          └────────────┬────────────┘
                        │
               ┌────────┴────────┐
               ▼                 ▼
           ALLOWED           FORBIDDEN
         get pods            get secrets
         list deployments    exec into pod
         view logs           delete resources
```

## The Two-Question Test
Before debugging any access issue, answer:
1. Is the IAM identity mapped? (check aws-auth or Access Entry)
2. Does the mapped group have a RoleBinding? (check `kubectl get rolebindings -n <ns>`)

If Q1 fails → Forbidden at the EKS API Server layer.
If Q2 fails → Forbidden at the RBAC layer.

## Revision Notes
- Draw this diagram from memory before touching any Terraform.
- Every module 01–05 implements one piece of this diagram.
- `kubectl auth can-i` tests the RBAC layer only — not the IAM layer.
