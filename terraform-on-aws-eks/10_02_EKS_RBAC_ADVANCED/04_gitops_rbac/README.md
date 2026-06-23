# 04 — GitOps RBAC (ArgoCD Deployer Role)

## Problem
Developers should not run `kubectl apply` directly against prod. ArgoCD does. But ArgoCD should not have cluster-admin — it only needs to deploy workloads into approved namespaces.

## Concepts
```
Git commit (developer)
        │
        ▼
ArgoCD detects diff
        │  (ArgoCD SA in network-account EKS)
        ▼
Applies manifests to dev-account EKS
        │  (cross-account IAM assume role)
        ▼
EKS Access Entry: argocd-role → group eks-argocd-deployer
        │  (ClusterRoleBinding)
        ▼
ClusterRole: argocd-deployer
  ALLOW: create/update/patch/delete deployments, services, configmaps, ingress
  ALLOW: get/list/watch all (to detect drift)
  DENY: secrets (managed by ESO), RBAC objects, cluster-scoped resources
```

> Builds on module 15_EKS_GitOps. Don't build this before ArgoCD is set up.

## Revision Notes
- ArgoCD = deployer, not admin. Principle of least privilege.
- Cross-account: ArgoCD SA assumes IAM role in target account via IRSA trust.
- Developers get read-only RBAC. ArgoCD gets deploy RBAC. Nobody gets admin except platform team.
