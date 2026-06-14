# IAM vs Kubernetes RBAC

## Problem
EKS uses two permission systems simultaneously. Understanding which one controls what prevents hours of debugging wrong-layer problems.

## Concepts

### IAM — AWS layer
Controls: Can this identity call AWS APIs? Can it describe the EKS cluster?
Objects: IAM User, IAM Role, IAM Policy
Scope: AWS account level

```
aws eks describe-cluster   ← IAM controls this
aws eks get-token          ← IAM controls this
```

### Kubernetes RBAC — K8s layer
Controls: Can this identity call the Kubernetes API?
Objects: Role, ClusterRole, RoleBinding, ClusterRoleBinding
Scope: Inside the cluster

```
kubectl get pods           ← RBAC controls this
kubectl get secrets        ← RBAC controls this
kubectl delete deployment  ← RBAC controls this
```

### The bridge
aws-auth ConfigMap or EKS Access Entry connects IAM identity → Kubernetes identity.

```
IAM Role ARN
     │  (aws-auth / Access Entry)
     ▼
Kubernetes username + groups
     │  (RoleBinding)
     ▼
RBAC permissions
```

## Revision Notes
- IAM = AWS gate. RBAC = Kubernetes gate. Both must be open.
- Granting IAM access alone does nothing inside the cluster.
- Granting RBAC alone does nothing if the IAM identity isn't mapped.
