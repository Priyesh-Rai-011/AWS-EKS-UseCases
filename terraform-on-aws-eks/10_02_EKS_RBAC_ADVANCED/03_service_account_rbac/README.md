# 03 — Service Account RBAC

## Problem
Humans aren't the only identities in a cluster. Pods also call the Kubernetes API. Prometheus scrapes pod metrics. ArgoCD applies manifests. ESO reads secrets. All of them need RBAC — often more than developers do.

## Concepts
```
Pod (e.g., Prometheus)
        │  mounted ServiceAccount token (automatic)
        ▼
Kubernetes API Server
        │  authenticates SA token
        ▼
ServiceAccount: prometheus/prometheus-sa
        │  ClusterRoleBinding
        ▼
ClusterRole: prometheus-reader
  ALLOW: get/list/watch pods, nodes, endpoints, services
```

ServiceAccount RBAC vs Human RBAC:
```
Human:         IAM → aws-auth → K8s User → RoleBinding → Role
ServiceAccount: SA token → K8s SA → RoleBinding → Role
```
No IAM in the path. Pure Kubernetes authentication.

## Why This Matters
- ESO (from module 07) uses a ServiceAccount with IRSA. The IRSA part = AWS API auth. The SA RBAC part = K8s API auth. Both exist simultaneously.
- Default ServiceAccount = exists in every namespace, has no permissions by default. Don't use it for workloads.

## Implementation
Terraform: IRSA role for SA (same pattern as module 06_EKS_IRSA)
k8s-manifests:
- 01-serviceaccount.yaml
- 02-clusterrole-sa-permissions.yaml
- 03-clusterrolebinding-sa.yaml
- 04-demo-pod-using-sa.yaml

## Revision Notes
- Every pod has a SA. Default SA = no permissions. Good.
- Never give a pod SA cluster-admin unless it literally manages the cluster.
- Disable auto-mount of SA token for pods that don't need K8s API access.

