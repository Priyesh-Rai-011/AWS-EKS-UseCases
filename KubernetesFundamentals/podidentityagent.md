# Pod Identity Agent

Pod Identity handles multiple microservices beautifully. Each microservice gets its **own association**. Here's how it works:

```
┌─────────────────────────────────────────────────────────────────┐
│                        TERRAFORM                                │
│                                                                 │
│  aws_eks_pod_identity_association "ums_app"                     │
│  ├── namespace       = "ums-app"                                │
│  ├── service_account = "ums-app-sa"                             │
│  └── role_arn        = aws_iam_role.ums_app_role.arn            │
│                        │                                        │
│  aws_eks_pod_identity_association "payments_app"                │
│  ├── namespace       = "payments"                               │
│  ├── service_account = "payments-sa"                            │
│  └── role_arn        = aws_iam_role.payments_role.arn           │
│                        │                                        │
│  aws_eks_pod_identity_association "notifications_app"           │
│  ├── namespace       = "notifications"                          │
│  ├── service_account = "notifications-sa"                       │
│  └── role_arn        = aws_iam_role.notifications_role.arn      │
│                                                                 │
└─────────────────────┬───────────────────────────────────────────┘
                      │ terraform apply (one shot, all 3)
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                   EKS ASSOCIATION TABLE                         │
│                   (AWS manages this)                            │
│                                                                 │
│   cluster + namespace + service_account  →  IAM Role           │
│   ──────────────────────────────────────────────────────        │
│   my-cluster / ums-app       / ums-app-sa       → role/ums      │
│   my-cluster / payments      / payments-sa      → role/pay      │
│   my-cluster / notifications / notifications-sa → role/notif    │
│                                                                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │ Pod Identity Agent (DaemonSet)
                           │ runs on every node, reads this table
                           │
          ┌────────────────┼─────────────────┐
          │                │                 │
          ▼                ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────┐
│   ums-app    │  │   payments   │  │  notifications   │
│     pod      │  │     pod      │  │      pod         │
│              │  │              │  │                  │
│ SA:ums-app-sa│  │ SA:payments- │  │ SA:notifs-sa     │
│              │  │    sa        │  │                  │
│ Gets creds   │  │ Gets creds   │  │ Gets creds for   │
│ for role/ums │  │ for role/pay │  │ role/notif only  │
│ only         │  │ only         │  │                  │
└──────────────┘  └──────────────┘  └──────────────────┘
       │                 │                   │
       ▼                 ▼                   ▼
  Secrets Manager    DynamoDB              SES Email
  (read secrets)     (read/write)          (send emails)
```

---

## How the Agent knows which role to give which pod

The Pod Identity Agent uses **3 things as a key** to look up the right role:

```
cluster name  +  namespace  +  service account name
     │                │                │
     └────────────────┴────────────────┘
                      │
                      ▼
              looks up association table
                      │
                      ▼
              returns the correct IAM role
              credentials for THAT pod only
```

So even if 50 pods are running on the same node, each gets **only its own role's credentials** — they cannot access each other's.

---

## The Kubernetes side stays dead simple

All 3 ServiceAccounts are just plain, identical-looking objects:

```yaml
# ums-app ServiceAccount — no annotation, no ARN, nothing AWS-specific
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ums-app-sa
  namespace: ums-app
---
# payments ServiceAccount — same, clean
apiVersion: v1
kind: ServiceAccount
metadata:
  name: payments-sa
  namespace: payments
---
# notifications ServiceAccount — same
apiVersion: v1
kind: ServiceAccount
metadata:
  name: notifications-sa
  namespace: notifications
```

All the "which app gets which AWS role" logic lives **only in Terraform** — your K8s manifests stay completely AWS-agnostic.