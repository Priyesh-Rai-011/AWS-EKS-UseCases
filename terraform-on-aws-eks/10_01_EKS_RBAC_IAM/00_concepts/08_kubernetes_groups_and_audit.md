# 08 — Kubernetes Groups and the Audit Trail Problem

---

## Where groups fit in the chain

EKS Access Entry maps an IAM role to two things: a username AND a list of groups.

```
IAM Role ARN: arn:aws:iam::123456789:role/eks-devops-admin-role
  → kubernetes username: "devops-admin"
  → kubernetes groups:   ["eks-devops-admins"]
```

The RoleBinding/ClusterRoleBinding binds to the GROUP, not the username:

```yaml
ClusterRoleBinding:
  subjects:
  - kind: Group
    name: eks-devops-admins     ← group name, not IAM ARN, not username
    apiGroup: rbac.authorization.k8s.io
  roleRef:
    kind: ClusterRole
    name: devops-admin-cluster-role
```

Full chain:

```
IAM User
  └── STS AssumeRole → IAM Role
        └── EKS Access Entry maps role ARN to:
              username: "devops-admin"
              groups:   ["eks-devops-admins"]
              └── Kubernetes sees authenticated identity
                    └── ClusterRoleBinding bound to group "eks-devops-admins"
                          └── ClusterRole defines verbs
                                └── API call: allowed or denied
```

---

## Why groups, not usernames directly

If 5 people all need devops-admin permissions, binding to group = one binding:

```
WITHOUT groups (bind to username):
  ClusterRoleBinding-1 → subject: User "alice"  → ClusterRole: devops-admin
  ClusterRoleBinding-2 → subject: User "frank"  → ClusterRole: devops-admin
  (repeat for every person)

WITH groups (bind to group):
  ClusterRoleBinding-1 → subject: Group "eks-devops-admins" → ClusterRole: devops-admin
  Access Entry for alice: groups=["eks-devops-admins"]
  Access Entry for frank: groups=["eks-devops-admins"]
  (one binding, N people can join the group)
```

Enterprise standard. Groups decouple RBAC definition from identity assignment.

---

## The audit trail problem

**Problem:** Multiple IAM roles map to the same k8s username.

```
Alice assumes eks-devops-admin-role → k8s username: "devops-admin"
Frank assumes eks-devops-admin-role → k8s username: "devops-admin"
```

EKS audit log sees:

```
"devops-admin" deleted deployment/payment-service at 14:32:07
```

Who was it? Kubernetes doesn't know. Both Alice and Frank look identical inside the cluster.

---

## How enterprises solve it

**Approach 1: One IAM role per person** (strictest, most audit-friendly)

```
alice-devops-role  → username: "alice"  → groups: ["eks-devops-admins"]
frank-devops-role  → username: "frank"  → groups: ["eks-devops-admins"]
```

EKS audit log now shows "alice" not "devops-admin". Clean attribution.
Downside: 50 engineers = 50 IAM roles. Role sprawl.

**Approach 2: STS session name passthrough** (what AWS gives you for free)

When a human assumes a role, STS bakes the IAM username into the session ARN:

```
arn:aws:sts::123456789:assumed-role/eks-devops-admin-role/alice
                                                          ^^^^^
                                              IAM username appears here
```

CloudTrail records this automatically:

```
CloudTrail event:
  userIdentity:
    type: AssumedRole
    arn: arn:aws:sts::123:assumed-role/eks-devops-admin-role/alice
    sessionIssuer:
      userName: alice
```

But — Kubernetes audit log STILL shows "devops-admin". Session detail only in CloudTrail.

**Cross-reference to find who did it:**

```
EKS audit log:
  "devops-admin" deleted deployment/payment-service
  timestamp: 14:32:07

CloudTrail:
  eks:AssumeRole at 14:31:55
  caller: arn:aws:iam::123:user/alice
  role assumed: eks-devops-admin-role

Conclusion: Alice. 37-second window between assume and action.
```

---

## What this repo implements

One IAM role per persona (not one per person — this is a learning environment):

```
eks-devops-admin-role → alice
eks-devops-role       → bob + frank (they share a role — audit via CloudTrail cross-ref)
```

In real production with strict compliance: one role per person for write-access roles.
Shared roles acceptable for readonly (no writes = audit trail less critical).

---

## Audit log setup

EKS audit logs go to CloudWatch Logs when enabled on the cluster:

```
EKS cluster → control plane logging → enable "audit"
  → /aws/eks/<cluster-name>/cluster log group
  → filter: { $.user.username = "devops-admin" && $.verb = "delete" }
```

Cross-reference with CloudTrail by timestamp to get real username.
