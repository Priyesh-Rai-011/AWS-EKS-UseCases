# EBS CSI Driver: Helm Chart vs Managed Addon

> My notes while learning EKS storage. Mostly read from AWS docs, some Medium blogs and asked Claude a lot of questions.

---

## First — What Even is Persistent Storage in Kubernetes?

Ok so when I first started learning K8s, I thought containers just store data inside themselves. That's wrong.

Containers are **ephemeral** — when a pod dies and restarts, everything inside it is gone. Database gone. Files gone. Clean slate. That's a problem if you're running something like MySQL.

So Kubernetes has this concept of **Volumes** — you attach external storage to a pod so the data survives pod restarts.

Now in AWS, the storage service is **EBS (Elastic Block Store)** — basically a virtual hard disk you attach to an EC2 instance (or in our case, a pod running on EKS).

---

## The Storage Concepts — StorageClass, PVC, PV

There are three objects you need to understand. They work together. I'll explain bottom-up.

### 1. PersistentVolume (PV) — the actual disk

A PV is a piece of real storage that exists in the cluster. It represents an actual EBS volume in AWS.

Think of it like: **PV = the hard disk**

```text
AWS Account
  └── EBS Volume (vol-0abc123...)  <-- this is the physical thing
        |
        | Kubernetes wraps it as:
        v
  PersistentVolume (pv-mysql-data)  <-- K8s object representing that disk
```

PVs can be created two ways:

- **Manually (Static)** — admin creates EBS volume, then manually writes a PV yaml pointing to it
- **Automatically (Dynamic)** — K8s creates the EBS volume on its own when someone asks for storage

We use dynamic provisioning. That's where StorageClass comes in.

---

### 2. StorageClass — the template/recipe for creating disks

StorageClass tells Kubernetes: "when someone asks for storage, here's how to create it."

Think of it like: **StorageClass = ordering form at a hardware store**

```text
StorageClass (ebs-gp3-sc)
  |
  |-- provisioner: ebs.csi.aws.com   <-- who will create the disk (EBS CSI Driver)
  |-- type: gp3                       <-- what kind of disk (gp3 = latest gen SSD)
  |-- volumeBindingMode: WaitForFirstConsumer  <-- explained below
  |-- reclaimPolicy: Delete           <-- delete EBS when PVC is deleted
```

This is our StorageClass (`01-storage-class.yaml`):

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

**Why `WaitForFirstConsumer`?** EBS volumes are tied to an Availability Zone (AZ). If you create the EBS volume before the pod is scheduled, it might land in `ap-south-1a` but your pod gets scheduled on a node in `ap-south-1b` — then the pod can't attach it. `WaitForFirstConsumer` says "don't create the EBS volume until we know which node the pod is going to run on, then create it in that AZ." Smart.

---

### 3. PersistentVolumeClaim (PVC) — the request for storage

A PVC is a pod saying "I need X amount of storage of Y type." It's a **claim** against a StorageClass.

Think of it like: **PVC = the purchase order / request**

```text
PVC (mysql-pvc)
  |-- requests: 5Gi storage
  |-- storageClassName: ebs-gp3-sc   <-- use THIS StorageClass
  |-- accessMode: ReadWriteOnce      <-- only one node can mount this at a time
```

This is our PVC (`02-mysql-pvc.yaml`):

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: ums-app
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-gp3-sc
  resources:
    requests:
      storage: 5Gi
```

**`ReadWriteOnce`** — EBS volumes can only be attached to one node at a time (unlike EFS which can be shared). So we use RWO.

---

## How All Three Work Together — The Full Flow

```text
                    YOU APPLY THIS
                         |
                         v
            kubectl apply -f 02-mysql-pvc.yaml

                         |
                         v

+------------------[ PVC Created ]------------------+
| name: mysql-pvc                                   |
| requests: 5Gi, storageClassName: ebs-gp3-sc       |
| status: Pending  <-- waiting for pod to schedule  |
+---------------------------------------------------+

                         |
                         | Pod gets scheduled on a node
                         v

+------------------[ StorageClass Kicks In ]---------+
| ebs-gp3-sc sees the PVC request                   |
| asks provisioner: ebs.csi.aws.com to create disk  |
+---------------------------------------------------+

                         |
                         v

+------------------[ EBS CSI Driver Acts ]----------+
| Calls AWS API: ec2:CreateVolume                   |
| Creates EBS gp3 volume in same AZ as the node     |
| vol-0abc1234567890xyz  (5 GiB, ap-south-1a)       |
+---------------------------------------------------+

                         |
                         v

+------------------[ PV Auto-Created ]---------------+
| K8s creates a PV object pointing to that EBS vol  |
| PV gets BOUND to the PVC                          |
| PVC status: Bound  <-- now ready                  |
+---------------------------------------------------+

                         |
                         v

+------------------[ Pod Mounts It ]----------------+
| MySQL pod starts                                  |
| EBS volume attached to EC2 node                   |
| mounted at /var/lib/mysql inside container        |
| MySQL reads/writes data there                     |
+---------------------------------------------------+
```

So the journey is:

```text
PVC (request) --> StorageClass (recipe) --> EBS CSI Driver (creates disk) --> PV (K8s object) --> Pod (uses it)
```

---

## What is the EBS CSI Driver Then?

So from the diagram above — the EBS CSI Driver is the **middleman between Kubernetes and AWS**. When Kubernetes needs an EBS volume created/deleted/attached/detached, it talks to the CSI driver, and the CSI driver calls the AWS EC2 APIs.

```text
Kubernetes (StorageClass controller)
    |
    | "hey I need a 5Gi gp3 volume in ap-south-1a"
    v
EBS CSI Driver (running as pods in kube-system)
    |
    | calls AWS EC2 API
    v
AWS  -->  ec2:CreateVolume  -->  EBS Volume Created
AWS  -->  ec2:AttachVolume  -->  EBS Volume Attached to Node
```

Without the EBS CSI Driver installed, Kubernetes has no idea how to talk to AWS EBS. PVCs would stay in `Pending` forever.

---

## Two Ways to Install the EBS CSI Driver

### Method 1: Managed EKS Addon (`04_ebs_csi_addon`)

AWS manages the lifecycle. You declare it in Terraform and AWS handles install, upgrades, and compatibility.

```hcl
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = "v1.45.0-eksbuild.2"
}
```

IAM method: **Pod Identity** (newer, 2023)

The EBS CSI controller pod needs AWS permissions to call `ec2:CreateVolume` etc. With Pod Identity:

```text
ebs-csi-controller pod
    |
    | "I need AWS creds"
    v
eks-pod-identity-agent (DaemonSet on every node)
    |
    | calls STS on behalf of the pod
    v
STS --> returns temp credentials for the IAM role
    |
    v
Pod can now call ec2:CreateVolume, ec2:AttachVolume, etc.
```

Trust principal in the IAM role is `pods.eks.amazonaws.com`.

### Method 2: Helm Chart (`03_ebs_csi_helm`)

You manage the lifecycle via Terraform's Helm provider. Installs the official community chart.

```hcl
resource "helm_release" "ebs_csi_driver" {
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.38.1"
  namespace  = "kube-system"
}
```

IAM method: **IRSA / OIDC** (older, battle-tested)

```text
ebs-csi-controller pod
    |
    | ServiceAccount has annotation:
    | eks.amazonaws.com/role-arn: arn:aws:iam::123:role/eks-helm-dev-ebs-csi-role
    v
Kubernetes mutating webhook injects AWS_ROLE_ARN env var into pod
    |
    v
AWS SDK in the pod sees the env var
    |
    | calls STS: AssumeRoleWithWebIdentity with OIDC token
    v
STS verifies token against OIDC provider --> returns temp credentials
    |
    v
Pod can now call ec2:CreateVolume, ec2:AttachVolume, etc.
```

The trust policy on the IAM role has an OIDC condition so only this specific ServiceAccount can assume it:

```text
Condition: StringEquals
  oidc.eks.ap-south-1.amazonaws.com/id/XXXX:sub
  = system:serviceaccount:kube-system:ebs-csi-controller-sa
```

---

## Side-by-Side Comparison

| Feature | Managed Addon | Helm Chart |
| --- | --- | --- |
| Who manages lifecycle | AWS | You (Terraform) |
| IAM method | Pod Identity | IRSA / OIDC |
| Version control | AWS addon versions | Helm chart semver |
| Upgrade | Change `addon_version` in TF | Change `version` in TF |
| Customization | Limited | Full (all Helm values) |
| Prerequisites | `eks-pod-identity-agent` addon | OIDC provider on cluster |
| Rollback | Hard (AWS controls it) | Easy (`helm rollback`) |
| AWS console visibility | Shows in EKS > Add-ons tab | Not visible there |
| Good for | Simple setups, less ops | GitOps, more control |

---

## Architecture Difference

### `04_ebs_csi_addon` — what one `terraform apply` creates

```text
VPC
 └── Bastion (SSM access, no public IP)
 └── EKS Cluster
       └── Node Group (t3.medium x2, public subnets)
       └── Addons:
             vpc-cni
             kube-proxy
             coredns
             metrics-server
             eks-pod-identity-agent       <-- needed for Pod Identity
       └── EBS CSI IAM Role (trust: pods.eks.amazonaws.com)
       └── Pod Identity Association (wires role --> ebs-csi-controller-sa)
       └── aws-ebs-csi-driver addon       <-- EBS CSI installed as managed addon
```

### `03_ebs_csi_helm` — what one `terraform apply` creates

```text
VPC
 └── Bastion (SSM access, no public IP)
 └── EKS Cluster + OIDC Provider           <-- OIDC needed for IRSA
       └── Node Group (t3.medium x2, public subnets)
       └── Addons:
             vpc-cni
             kube-proxy
             coredns
             metrics-server
             (no pod-identity-agent needed)
       └── EBS CSI IAM Role (trust: sts:AssumeRoleWithWebIdentity via OIDC)
       └── helm install aws-ebs-csi-driver  <-- EBS CSI installed via Helm
             (role ARN injected as SA annotation automatically by Terraform)
```

---

## When to Use Which

**Use Managed Addon when:**

- You want AWS to handle version compatibility with Kubernetes
- Minimal ops overhead is priority
- Running in regulated environment where AWS-managed = auditable

**Use Helm Chart when:**

- You need fine-grained Helm values customization
- Your org uses Helm/ArgoCD/Flux for all K8s installs
- You need to pin specific patch versions not available as addons
- IRSA is already your standard IAM pattern across workloads
