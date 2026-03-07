# Introduction to karpenter

### What do we use in the ESK Auto Scaling

- OPTION 1 — **scaling_config only (manual boundaries)**
    Used by  :   Small teams, dev/test environments, cost-controlled setups
    Scales   :   Only if YOU change desired_size manually or via CI/CD
    Verdict  :   Fine for learning. Not production autoscaling.

- OPTION 2 — **Cluster Autoscaler**
    Used by  :   Older production setups, teams that haven't migrated yet
    Scales   :   Based on pending pods — adds nodes when pods can't schedule
    Verdict  :   Works, but slow (2-3 min) and complicated to configure.
             Being replaced everywhere.

- OPTION 3 — **Karpenter**
    Used by  :   Modern production setups, AWS-recommended, most new projects
    Scales   :   Based on pending pods — but faster, smarter, cheaper
    Verdict  :   This is what the industry is moving to. AWS built it.
                 EKS docs recommend it over Cluster Autoscaler.

#### Why carpenter won?
```
CLUSTER AUTOSCALER               KARPENTER
─────────────────────────────    ─────────────────────────────────────
Tied to node groups              Provisions nodes directly (no ASG needed)
Scales in ~2-3 minutes           Scales in ~30-60 seconds
You define instance types        It picks the best + cheapest instance itself
Needs IAM role + helm chart      Needs IAM role + helm chart
Hard to mix Spot + On-Demand     Native Spot + On-Demand mixing built in
Node group per instance family   One Karpenter NodePool covers everything
```


#### So, one questions arises is - Now we don't need to configure the `scaling _config` in the `aws_nodegroup` resource block in terraform?

Not exactly — you still need scaling_config. 
Here is the honest truth:
    - With Karpenter you still keep scaling_config — but for a different reason

```
WITHOUT KARPENTER:
  scaling_config controls your actual workload nodes
  You rely on it for all your application pods

WITH KARPENTER:
  scaling_config is only for a small, fixed "bootstrap" node group
  Just enough nodes to run Karpenter itself
  Karpenter then provisions ALL other nodes directly
```

#### The setup
```
YOUR EKS CLUSTER
│
├── Node Group (Terraform — small, fixed)
│     scaling_config {
│       desired_size = 2   ← just enough to run Karpenter pod
│       min_size     = 2   ← fixed, never scales down
│       max_size     = 2   ← fixed, never scales up
│     }
│     Purpose: runs Karpenter pod + system addons (coredns, vpc-cni etc.)
│
└── Karpenter Nodes (Karpenter manages these — NOT Terraform)
      Your actual application pods run here
      Karpenter creates and deletes these nodes directly
      No node group. No scaling_config. No ASG.
```


---
# How Karpenter Provisions Nodes

Instead of scaling_config, you define a NodePool and EC2NodeClass in Kubernetes YAML:

yaml
```
# NodePool — replaces scaling_config min/max/desired
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      nodeClassRef:
        name: default
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]   # mix both — Karpenter picks cheapest
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["t3.medium", "t3.large", "m5.large"]  # give it options

  limits:
    cpu: 100       # max total CPU across all Karpenter nodes
    memory: 400Gi  # max total memory

  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized  # removes idle nodes automatically
```
Then we write this configuration.
yaml
```
# EC2NodeClass — defines WHERE nodes go (your VPC, subnets, SGs)
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  role: "${cluster_name}-karpenter-node-role"   # IAM role for Karpenter nodes
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${cluster_name}"  # finds your private subnets by tag
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${cluster_name}"  # finds your node SG by tag
```
---

## What Karpenter Does at Runtime
```
Pod is Pending — no node has enough CPU/memory
        │
        ▼
Karpenter sees the pending pod in ~5 seconds
        │
        ▼
Reads pod's resource requests (cpu: 500m, memory: 256Mi)
        │
        ▼
Picks the cheapest instance type that fits
from your NodePool requirements list
        │
        ▼
Calls EC2 API directly — CreateInstance
(No ASG. No node group update. Direct.)
        │
        ▼
Node is Ready in ~30-60 seconds
        │
        ▼
Pod schedules and starts ✅

Later — pod is deleted, node sits idle
        │
        ▼
Karpenter consolidation kicks in after ~30s
        │
        ▼
Terminates the idle node automatically 💰
```
