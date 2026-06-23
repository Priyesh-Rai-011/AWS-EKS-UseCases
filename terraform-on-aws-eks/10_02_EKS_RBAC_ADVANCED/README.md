# 10_02 — EKS RBAC Advanced

## Problem
Module 10 covers human access with IAM Users and Roles. Real production clusters have more: modern Access Entries instead of aws-auth, workload identities (Service Accounts), GitOps deployer roles, and hardening against privilege escalation.

## Concepts
- EKS Access Entries = modern replacement for aws-auth ConfigMap
- Service Account RBAC = pods have identities and need permissions too
- GitOps RBAC = ArgoCD needs deploy rights, not humans
- RBAC hardening = block dangerous verbs (exec, secrets, escalate)

## Implementation
| Folder | Builds on |
|--------|-----------|
| 01_access_entries | Replaces aws-auth from module 10 |
| 02_identity_center | Conceptual only — no sandbox needed |
| 03_service_account_rbac | IRSA from module 06 + RBAC layer |
| 04_gitops_rbac | ArgoCD deployer role (builds on 15_EKS_GitOps) |
| 05_rbac_hardening | Security layer on top of all earlier modules |

## Revision Notes
- Build module 10 completely before starting here.
- 02_identity_center = theory only. Real implementation needs AWS Organizations setup.
- 04_gitops_rbac pairs with module 15_EKS_GitOps.
