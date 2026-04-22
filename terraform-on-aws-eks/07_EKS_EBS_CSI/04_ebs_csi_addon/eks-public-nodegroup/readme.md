# EKS Public Nodegroup — EBS CSI Full Stack

> "A public nodegroup is NOT less secure because the nodes have public IPs.
> It's less secure because you haven't thought carefully about security groups.
> Understand the difference."

---

## What 'Public Nodegroup' Means

Your EC2 worker nodes are placed in **public subnets**. They get public IP
addresses. They can reach the internet directly through the Internet Gateway
without going through NAT.

```
  Internet
     │
     │  (direct path)
     ▼
  Internet Gateway (IGW)
     │
     ├──▶  Public Subnet 10.0.1.0/24  ──▶  Node 1 (public IP)
     ├──▶  Public Subnet 10.0.2.0/24  ──▶  Node 2 (public IP)
     └──▶  Public Subnet 10.0.3.0/24  ──▶  Node 3 (public IP) [max scale]
```

The nodes can pull Docker images from ECR, reach AWS APIs, download
system updates — all without NAT. Outbound is free through IGW.

The bastion still lives in a PRIVATE subnet. It doesn't need a public IP
because SSM is how you connect to it.

---

## Full Architecture

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │  AWS Region: ap-south-1                                              │
  │                                                                      │
  │  ┌────────────────────────────────────────────────────────────────┐  │
  │  │  VPC: 10.0.0.0/16                                              │  │
  │  │                                                                │  │
  │  │  ┌─────────────────────────────────────────────────────────┐  │  │
  │  │  │  PUBLIC SUBNETS (nodes live here)                        │  │  │
  │  │  │  10.0.1.0/24  │  10.0.2.0/24  │  10.0.3.0/24           │  │  │
  │  │  │               │               │                         │  │  │
  │  │  │  ┌──────────┐ │ ┌──────────┐  │  ┌─────────────────┐   │  │  │
  │  │  │  │ Node 1   │ │ │ Node 2   │  │  │   NAT Gateway   │   │  │  │
  │  │  │  │ t3.medium│ │ │ t3.medium│  │  │ (for private    │   │  │  │
  │  │  │  │ public IP│ │ │ public IP│  │  │  subnet egress) │   │  │  │
  │  │  │  └────┬─────┘ │ └────┬─────┘  │  └─────────────────┘   │  │  │
  │  │  │       │        │      │        │                         │  │  │
  │  │  └───────┼────────┼──────┼────────┼─────────────────────────┘  │  │
  │  │          │        │      │        │                             │  │
  │  │          ▼        ▼      ▼        ▼                             │  │
  │  │  ┌─────────────────────────────────────────────────────────┐   │  │
  │  │  │  PRIVATE SUBNETS                                         │   │  │
  │  │  │  10.0.11.0/24  │  10.0.12.0/24  │  10.0.13.0/24        │   │  │
  │  │  │                                                          │   │  │
  │  │  │  ┌────────────────────────────────────────────────────┐  │   │  │
  │  │  │  │  Bastion EC2 (t3.micro)                            │  │   │  │
  │  │  │  │  No public IP. Egress 443 only. SSM access.        │  │   │  │
  │  │  │  │  Has: kubectl + kubeconfig + repo cloned at boot   │  │   │  │
  │  │  │  └────────────────────────────────────────────────────┘  │   │  │
  │  │  └─────────────────────────────────────────────────────────┘   │  │
  │  │                                                                 │  │
  │  │  ┌─────────────────────────────────────────────────────────┐   │  │
  │  │  │  DATABASE SUBNETS (reserved for RDS — unused here)       │   │  │
  │  │  │  10.0.21.0/24  │  10.0.22.0/24  │  10.0.23.0/24        │   │  │
  │  │  └─────────────────────────────────────────────────────────┘   │  │
  │  │                                                                 │  │
  │  │  ┌──────────────────────────────────────┐                      │  │
  │  │  │  EKS Control Plane (AWS-managed)     │                      │  │
  │  │  │  Endpoint: public + private          │                      │  │
  │  │  │  PrivateLink ENI in private subnet   │                      │  │
  │  │  └──────────────────────────────────────┘                      │  │
  │  │                                                                 │  │
  │  │  ┌──────────────────────────────────────┐                      │  │
  │  │  │  EBS Volume (gp3, 5GB)               │                      │  │
  │  │  │  Attached to whichever node runs     │                      │  │
  │  │  │  the postgres pod                    │                      │  │
  │  │  └──────────────────────────────────────┘                      │  │
  │  └────────────────────────────────────────────────────────────────┘  │
  └──────────────────────────────────────────────────────────────────────┘
```

---

## Kubernetes Workloads (what runs inside the cluster)

```
  Namespace: ums-app
  ──────────────────────────────────────────────────────────────────
  │
  │  StorageClass: ebs-gp3-sc
  │    provisioner: ebs.csi.aws.com
  │    volumeBindingMode: WaitForFirstConsumer  ← IMPORTANT (see below)
  │    reclaimPolicy: Retain                    ← data survives PVC delete
  │    type: gp3, encrypted: true
  │
  │  PersistentVolumeClaim: postgres-pvc
  │    storageClassName: ebs-gp3-sc
  │    accessModes: ReadWriteOnce
  │    storage: 5Gi
  │    status: Pending → Bound (once postgres pod is scheduled)
  │
  │  ┌──────────────────────────────────────────┐
  │  │  postgres Deployment (1 replica)         │
  │  │                                          │
  │  │  image: postgres:16-alpine               │
  │  │  env from: postgres-secret               │  ← DB name/user/pass
  │  │  env from: postgres-config               │
  │  │                                          │
  │  │  volumeMount:                            │
  │  │    /var/lib/postgresql/data              │
  │  │         ▲                                │
  │  │         │ mounted from EBS via CSI       │
  │  └─────────┼────────────────────────────────┘
  │             │
  │             │  EBS CSI Driver (kube-system) manages this
  │             ▼
  │  EBS Volume: gp3, 5GB (AWS creates this on first pod schedule)
  │
  │  Service: postgres-svc (ClusterIP :5432)
  │    Only reachable inside the cluster. Not exposed to internet.
  │
  │  ┌──────────────────────────────────────────┐
  │  │  ums-app Deployment (2 replicas)         │
  │  │                                          │
  │  │  image: priyeshrai711/ums-app:latest     │
  │  │  port: 8080                              │
  │  │  APP_PROFILE: prod                       │
  │  │  DB_URL: jdbc:postgresql://              │
  │  │          postgres-svc:5432/umsdb         │
  │  │  DB_USERNAME: from postgres-secret       │
  │  │  DB_PASSWORD: from postgres-secret       │
  │  │                                          │
  │  │  readinessProbe: GET /api/users/health   │  ← pod only gets traffic
  │  │  livenessProbe:  GET /api/users/health   │    when app is ready
  │  └──────────────────────────────────────────┘
  │
  │  Service: ums-loadbalancer-svc (LoadBalancer)
  │    port 80 → targetPort 8080
  │    AWS creates an NLB. You get an EXTERNAL-IP DNS name.
  │    Hit: http://<EXTERNAL-IP>/api/users
```

---

## Why `WaitForFirstConsumer` Matters

This is something freshers always get wrong. Pay attention.

```
  WRONG assumption:
  "PVC is created → EBS volume is created immediately"

  REALITY with WaitForFirstConsumer:
  "PVC is created → status: Pending → waits"
  "Pod is scheduled to a node in AZ ap-south-1a"
  "THEN EBS volume is created in ap-south-1a"
  "THEN volume is attached to the node"
  "THEN pod starts"

  WHY this matters:
  EBS volumes are AZ-specific. If the volume is created in AZ-1a
  but the pod schedules to a node in AZ-1b, the pod can NEVER start.
  WaitForFirstConsumer ensures the volume is created in the SAME AZ
  as the node that will use it.
```

---

## IAM Roles — Who Can Do What

```
  Role 1: eks-public-dev-cluster-role
  ├── Assumed by: eks.amazonaws.com (AWS EKS service itself)
  └── Permissions: create ENIs, manage SGs, create load balancers in your VPC

  Role 2: eks-public-dev-node-role
  ├── Assumed by: ec2.amazonaws.com (your EC2 worker nodes)
  └── Permissions:
      ├── AmazonEKSWorkerNodePolicy    → join the cluster, report status
      ├── AmazonEKS_CNI_Policy         → assign pod IPs via secondary ENIs
      ├── AmazonEC2ContainerRegistryReadOnly → pull images from ECR
      └── AmazonSSMManagedInstanceCore → SSM agent on nodes

  Role 3: eks-public-dev-ebs-csi-role
  ├── Assumed by: pods.eks.amazonaws.com  ← Pod Identity (NOT eks.amazonaws.com)
  ├── Bound to:   kube-system/ebs-csi-controller-sa  (via pod identity association)
  └── Permissions: AmazonEBSCSIDriverPolicy
      (create/attach/detach/delete EBS volumes)

  Role 4: eks-public-dev-bastion-ssm-role
  ├── Assumed by: ec2.amazonaws.com (the bastion EC2 instance)
  └── Permissions:
      ├── AmazonSSMManagedInstanceCore  → SSM session access
      └── eks:DescribeCluster, eks:ListClusters, ec2:Describe*  → read-only lookup
```

---

## EKS Addons — What Each One Does

```
  Addon             Version                  Purpose
  ─────────────────────────────────────────────────────────────────────
  vpc-cni           v1.19.5-eksbuild.3       Assigns real VPC IPs to pods.
                                             Each pod gets an IP from your
                                             subnet CIDR — not a fake overlay.

  kube-proxy        v1.33.0-eksbuild.2       Programs iptables rules on each
                                             node for Service → Pod routing.
                                             When you hit ClusterIP:port,
                                             kube-proxy routes it to a pod.

  coredns           v1.12.1-eksbuild.2       Internal DNS. postgres-svc resolves
                                             to 10.x.x.x inside the cluster.
                                             Without this, pods can't find each other
                                             by service name.

  eks-pod-identity-agent  v1.3.4-eksbuild.1  DaemonSet on every node. Intercepts
                                             credential requests from pods and hands
                                             them scoped IAM tokens. MUST exist
                                             before pod identity associations.

  aws-ebs-csi-driver  v1.45.0-eksbuild.2    Talks to AWS EC2 API to create and
                                             attach EBS volumes when a PVC is claimed.
                                             Uses the ebs-csi-role via Pod Identity.

  metrics-server    v0.7.2-eksbuild.1        Collects CPU/memory metrics from nodes
                                             and pods. Powers kubectl top node/pod
                                             and Horizontal Pod Autoscaler.
```

---

## Terraform Module Dependency Graph

```
  backend.tf                    providers.tf
  (remote state config)         (AWS provider)
         │                             │
         └──────────────┬──────────────┘
                        │
                   variables.tf + locals.tf
                        │
                      main.tf
                        │
          ┌─────────────┼──────────────┐
          │             │              │
     module.vpc   module.bastion  module.eks
          │             │              │
          │      needs vpc.vpc_id      │
          │      and vpc.private_      │
          │      subnet_ids[0]         │
          │             │              │
          │      outputs:              │
          │      bastion_role_arn ─────▶ var.bastion_role_arn
          │                            │
          └───────────────────────────▶│
               vpc outputs used by eks │
               (subnet IDs, CIDRs)     │
                                       │
                                  outputs.tf
                            (cluster endpoint,
                             kubectl command,
                             SSM connect command)
```

---

## How to Deploy

```bash
# Step 1 — Provision infrastructure
cd eks-public-nodegroup/terraform
terraform init
terraform plan    # read this carefully before applying
terraform apply   # takes ~15-20 minutes

# Step 2 — Get connection command from output
terraform output ssm_connect_command
# looks like: aws ssm start-session --target i-0abc123 --region ap-south-1

# Step 3 — Connect to bastion
aws ssm start-session --target i-0abc123 --region ap-south-1

# Step 4 — On the bastion, apply manifests
cd ~/eks-repo/terraform-on-aws-eks/07_EKS_EBS_CSI/04_ebs_csi_addon/eks-public-nodegroup/k8s-manifests
bash apply-all.sh

# Step 5 — Watch pods come up
kubectl get pods -n ums-app -w

# Step 6 — Get the public endpoint
kubectl get svc -n ums-app ums-loadbalancer-svc
# Copy EXTERNAL-IP. Wait 2-3 mins for LB to provision.

# Step 7 — Test the API
curl http://<EXTERNAL-IP>/api/users/health
curl -X POST http://<EXTERNAL-IP>/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com"}'
curl http://<EXTERNAL-IP>/api/users

# Step 8 — When done learning, destroy EVERYTHING
terraform destroy
```

---

## Common Mistakes (Freshers Always Make These)

```
  ✗ Running kubectl from your laptop without configuring kubeconfig
    Fix: use the bastion, or run: terraform output configure_kubectl

  ✗ Applying manifests before the EBS CSI addon is ready
    Fix: wait for terraform apply to fully complete before kubectl apply

  ✗ Deleting the PVC and expecting data to survive
    Fix: reclaimPolicy: Retain means the EBS volume survives PVC deletion
         but you need to manually re-bind it to a new PVC

  ✗ Wondering why postgres pod stays Pending
    Fix: check PVC status, check EBS CSI pod logs in kube-system
         kubectl describe pvc postgres-pvc -n ums-app
         kubectl logs -n kube-system -l app=ebs-csi-controller

  ✗ Deleting the cluster without running terraform destroy
    Fix: always terraform destroy — otherwise EBS volumes and LBs
         created by Kubernetes won't be cleaned up and will keep billing you
```

---

## Difference vs Private Nodegroup (One Line)

```
  Public:   aws_eks_node_group subnet_ids = var.public_subnet_ids
  Private:  aws_eks_node_group subnet_ids = var.private_subnet_ids

  Everything else — VPC, bastion, addons, manifests — is identical.
```
