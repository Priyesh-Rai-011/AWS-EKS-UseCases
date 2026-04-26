# EKS + EBS CSI Addon — Full Stack Deployment

> "Before you touch a single line of Terraform, you need to understand WHY we're
> doing this. Infrastructure without understanding is just cargo-cult engineering."
> — Every good senior engineer, ever.

---

## The Problem We're Solving

You have a Spring Boot app (UMS) that needs a database (PostgreSQL).
PostgreSQL needs to **persist data to disk**. On Kubernetes, containers are
ephemeral — when a pod dies, everything inside it dies too.

So the question is: **where does the data live?**

On bare metal you'd just write to `/var/lib/postgresql/data`.
On Kubernetes running on AWS, you need an **EBS volume** — a real AWS disk —
that outlives the pod, gets reattached when the pod reschedules, and doesn't
lose your data when the cluster autoscales.

That's what this entire folder is about.

---

## The Big Picture

```
  YOUR LAPTOP
  ──────────────────────────────────────────────────────────────────────
  │                                                                    │
  │   terraform apply                                                  │
  │        │                                                           │
  │        ▼                                                           │
  │   ┌─────────────────────────────────────────────────────────┐     │
  │   │                    AWS Account                           │     │
  │   │                                                         │     │
  │   │  ┌──────────────────────────────────────────────────┐   │     │
  │   │  │                   VPC  10.0.0.0/16               │   │     │
  │   │  │                                                  │   │     │
  │   │  │  Public Subnets         Private Subnets          │   │     │
  │   │  │  10.0.1-3.0/24          10.0.11-13.0/24          │   │     │
  │   │  │  ┌──────────────┐       ┌──────────────────────┐ │   │     │
  │   │  │  │  NAT Gateway │       │   EKS Worker Nodes   │ │   │     │
  │   │  │  │  (outbound   │◀──────│   (your app pods     │ │   │     │
  │   │  │  │   internet)  │       │    run here)         │ │   │     │
  │   │  │  └──────────────┘       └──────────────────────┘ │   │     │
  │   │  │                                    │              │   │     │
  │   │  │  ┌──────────────┐                  │ EBS CSI      │   │     │
  │   │  │  │   Bastion    │                  │ attaches     │   │     │
  │   │  │  │   (private   │                  ▼ disk here    │   │     │
  │   │  │  │   subnet)    │       ┌──────────────────────┐  │   │     │
  │   │  │  │   SSM only   │       │   EBS Volume (gp3)   │  │   │     │
  │   │  │  └──────────────┘       │   PostgreSQL data    │  │   │     │
  │   │  │        │ SSM            └──────────────────────┘  │   │     │
  │   │  │        ▼                                          │   │     │
  │   │  │  kubectl apply manifests ──────────────────────▶  │   │     │
  │   │  │  (from bastion, not your laptop)                  │   │     │
  │   │  └──────────────────────────────────────────────────┘   │     │
  │   └─────────────────────────────────────────────────────────┘     │
  └──────────────────────────────────────────────────────────────────--┘
```

---

## Why Two Variants?

This folder has two sub-projects:

```
04_ebs_csi_addon/
├── eks-public-nodegroup/    ← Worker nodes sit in PUBLIC subnets
└── eks-private-nodegroup/   ← Worker nodes sit in PRIVATE subnets
```

"Why does it matter where the nodes sit?"

Great question. Think of it like this:

```
PUBLIC NODE GROUP                    PRIVATE NODE GROUP
─────────────────────────────────    ─────────────────────────────────
Nodes have PUBLIC IPs                Nodes have NO public IPs
Internet can reach nodes directly    Nodes reach internet via NAT GW
Lower security boundary              Higher security boundary
Simpler (no NAT cost)                Production-grade setup
Fine for learning / dev              What real companies use
```

The Kubernetes manifests (your app, postgres, storage) are **identical** in
both. The only thing that changes is WHERE the EC2 nodes that run those pods
are placed inside the VPC.

---

## The Three-Layer Stack

Every real Kubernetes deployment has three layers. Learn this mental model —
it applies everywhere:

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 3 — APPLICATION                                          │
│                                                                 │
│  What runs INSIDE the cluster (k8s manifests)                   │
│                                                                 │
│  Namespace → StorageClass → PVC → Postgres → UMS App → LB Svc  │
│                                                                 │
│  YOU control this. Applied via bastion using kubectl.           │
└─────────────────────────────────────────────────────────────────┘
         ▲ runs on top of
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 2 — KUBERNETES INFRASTRUCTURE                            │
│                                                                 │
│  The cluster itself + addons (Terraform creates this)           │
│                                                                 │
│  EKS Control Plane + Node Group + EBS CSI + CoreDNS + VPC CNI  │
│                                                                 │
│  AWS manages the control plane. You manage the node groups.     │
└─────────────────────────────────────────────────────────────────┘
         ▲ runs on top of
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 1 — NETWORK FOUNDATION                                   │
│                                                                 │
│  VPC + Subnets + IGW + NAT GW + Route Tables (Terraform)        │
│                                                                 │
│  This is the plumbing. Every packet flows through this layer.   │
└─────────────────────────────────────────────────────────────────┘
```

---

## The EBS CSI Driver — What It Actually Does

"EBS CSI" sounds complicated. It isn't. Here's what it does:

```
  Your pod says: "I need 5GB of disk space."
       │
       │  (via PersistentVolumeClaim in YAML)
       ▼
  Kubernetes scheduler sees the PVC request
       │
       ▼
  EBS CSI Controller (a pod in kube-system) wakes up
       │
       │  calls AWS API: "Create an EBS gp3 volume, 5GB, in this AZ"
       ▼
  AWS creates the EBS volume
       │
       │  attaches it to the EC2 node where your pod is scheduled
       ▼
  Volume is mounted into the pod at /var/lib/postgresql/data
       │
       ▼
  Postgres writes data. Pod dies. Node reboots.
  EBS volume SURVIVES. Data is safe. Volume reattaches to next pod.
```

This is why EBS CSI needs its own IAM role — it's calling AWS APIs
(`ec2:CreateVolume`, `ec2:AttachVolume`, etc.) on your behalf.

---

## Pod Identity — The Modern Way to Give Pods AWS Permissions

Old way (IRSA): complicated OIDC + annotation dance.
New way (Pod Identity): clean, simple, no OIDC setup needed.

```
  OLD WAY — IRSA
  ──────────────────────────────────────────────────
  1. Get OIDC provider URL from cluster
  2. Create IAM role with trust policy pointing to OIDC URL
  3. Annotate the Kubernetes service account
  4. Hope you got the condition string right
  5. Debug for 2 hours when it doesn't work

  NEW WAY — Pod Identity (what we use here)
  ──────────────────────────────────────────────────
  1. Create IAM role with trust: pods.eks.amazonaws.com
  2. Run: aws_eks_pod_identity_association
         namespace  = "kube-system"
         service_account = "ebs-csi-controller-sa"
         role_arn   = <your role>
  3. Done. Pod picks up the credentials automatically.
```

The `eks-pod-identity-agent` addon (a DaemonSet on every node) is what
intercepts the pod's credential request and hands it the right IAM token.
**This addon must exist before the association is created.**

---

## The Bastion — Why We Don't Use kubectl From Our Laptop

"Why can't I just run kubectl from my laptop?"

You can — but only if `endpoint_public_access = true`.
Even then, in a real company, the cluster API endpoint is private.
The bastion is the bridge:

```
  Your Laptop
       │
       │  aws ssm start-session --target <instance-id>
       │  (encrypted tunnel, no SSH key, no port 22, no public IP on bastion)
       ▼
  Bastion EC2 (private subnet)
       │
       │  has kubeconfig already configured at boot (user_data)
       │  has kubectl installed
       │  has the repo cloned at ~/eks-repo
       ▼
  kubectl apply -f k8s-manifests/
       │
       ▼
  EKS API Server
       │
       ▼
  Pods created on worker nodes
```

SSM Session Manager = VPN-lite. The bastion reaches out to AWS SSM endpoints
over port 443 (outbound). Your laptop connects through that. No inbound rules
needed on the bastion security group at all.

---

## Deployment Order — This Sequence Matters

```
  Step 1: terraform init && terraform apply
          Creates: VPC → Bastion → EKS cluster → Node group
                   → Addons (in order) → Pod Identity → EBS CSI addon
          Time: ~15-20 minutes

  Step 2: terraform output ssm_connect_command
          Copy the command. Run it.

  Step 3: On the bastion:
          cd ~/eks-repo/.../k8s-manifests
          bash apply-all.sh

  Step 4: Watch it come up:
          kubectl get pods -n ums-app -w

  Step 5: Get the LoadBalancer URL:
          kubectl get svc -n ums-app
          Copy EXTERNAL-IP. Hit it in your browser.
          curl http://<EXTERNAL-IP>/api/users/health
```

---

## What Each Terraform Module Does

```
  main.tf (root)
  ├── module.vpc
  │     Creates all networking. Nothing can exist without this.
  │     Output: VPC ID, subnet IDs, subnet CIDRs
  │
  ├── module.bastion
  │     Creates the EC2 jump host. Needs VPC to exist first.
  │     Output: bastion_role_arn (used by EKS access entry)
  │
  └── module.eks
        Creates everything Kubernetes.
        Needs: VPC outputs + bastion_role_arn
        Creates: cluster → node group → addons → access entry
```

Notice: `module.bastion` is created BEFORE `module.eks` in the dependency
graph. That's intentional — the EKS access entry needs the bastion's IAM role
ARN to grant it cluster-admin.

---

## Folder Structure

```
04_ebs_csi_addon/
│
├── readme.md                        ← you are here
│
├── eks-public-nodegroup/
│   ├── readme.md                    ← public nodegroup deep-dive
│   ├── k8s-manifests/               ← apply these from bastion
│   │   ├── 00-namespace.yaml
│   │   ├── 01-storage-class.yaml    ← defines EBS gp3 StorageClass
│   │   ├── 02-postgres-pvc.yaml     ← claims 5GB EBS volume
│   │   ├── 03-postgres-secret.yaml  ← DB credentials (Opaque Secret)
│   │   ├── 04-postgres-configmap.yaml
│   │   ├── 05-postgres-deployment.yaml  ← PostgreSQL pod + EBS mount
│   │   ├── 06-postgres-clusterip-svc.yaml
│   │   ├── 07-ums-configmap.yaml    ← DB_URL, APP_PROFILE
│   │   ├── 08-ums-deployment.yaml   ← Spring Boot app, 2 replicas
│   │   ├── 09-ums-loadbalancer-svc.yaml  ← AWS LB, public endpoint
│   │   └── apply-all.sh             ← run this on bastion
│   └── terraform/
│       ├── backend.tf / providers.tf / locals.tf
│       ├── variables.tf / terraform.tfvars / main.tf / outputs.tf
│       └── modules/
│           ├── vpc/     bastion/     eks/
│
└── eks-private-nodegroup/
    ├── readme.md                    ← private nodegroup deep-dive
    ├── k8s-manifests/               ← identical to public
    └── terraform/                   ← same structure, nodes in private subnets
```

---

## Key Terraform State Files (Remote Backend)

Both variants use the same S3 bucket but different state file paths:

```
  S3 bucket: learning-remotebackend2
  DynamoDB:  learning-remotebackend  (for state locking)

  Public:   terraform-on-aws-eks/07-ebs-csi/public-nodegroup/terraform.tfstate
  Private:  terraform-on-aws-eks/07-ebs-csi/private-nodegroup/terraform.tfstate
```

Never run both variants at the same time in the same AWS account unless you
change the cluster names and VPC CIDRs to avoid conflicts.

---

## Cost Warning

Running this will cost real AWS money. Approximate per-hour:
- 2x t3.medium nodes: ~$0.083/hr
- NAT Gateway: ~$0.045/hr + data transfer
- EBS volumes: ~$0.08/GB/month
- EKS cluster: $0.10/hr

**Always run `terraform destroy` when done learning.**
