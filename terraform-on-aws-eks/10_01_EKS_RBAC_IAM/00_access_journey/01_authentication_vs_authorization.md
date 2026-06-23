# Authentication vs Authorization

## Problem
Two different questions get asked on every `kubectl` call. Most beginners treat them as one thing and get confused when access fails.

## Concepts

```
kubectl get pods
        │
        ▼
Q1: WHO ARE YOU?          ← Authentication (AuthN)
    Answered by: IAM
        │
        ▼
Q2: WHAT CAN YOU DO?      ← Authorization (AuthZ)
    Answered by: Kubernetes RBAC
```

These are two separate systems. A failure in either = access denied.

| | Authentication | Authorization |
|-|---------------|---------------|
| Question | Who are you? | What can you do? |
| System | AWS IAM | Kubernetes RBAC |
| Objects | IAM User, IAM Role | Role, ClusterRole, RoleBinding |
| Failure message | `error: You must be logged in` | `Error from server (Forbidden)` |

## Revision Notes
- AuthN = identity. AuthZ = permissions.
- IAM handles AuthN for EKS. RBAC handles AuthZ.
- You can be perfectly authenticated and still get Forbidden — that's an AuthZ failure.
