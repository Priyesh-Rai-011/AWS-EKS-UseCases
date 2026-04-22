# EKS Private Nodegroup — EBS CSI Full Stack

> "If someone asks you what the difference between public and private nodegroups
> is, and your answer is 'private is more secure' — you're half right and
> completely wrong. The right answer is: private nodegroups give you defence-in-
> depth by removing a network attack surface. Security is the result of the whole
> architecture, not one setting."

---

## What 'Private Nodegroup' Means

Your EC2 worker nodes live in **private subnets**. They have NO public IP
addresses. They cannot be reached from the internet directly. They reach the
internet for outbound traffic (ECR image pulls, AWS API calls, OS updates)
through a NAT Gateway sitting in the public subnet.

```
  Internet
     │
     │  (outbound only — nodes initiate, internet cannot initiate back)
     ▼
  Internet Gateway
     │
     ▼
  NAT Gateway (sits in public subnet, has Elastic IP)
     │
     │  ◀── all outbound traffic from private nodes goes through here
     ▼
  Private Subnet 10.0.11.0/24  ──▶  Node 1 (NO public IP)
  Private Subnet 10.0.12.0/24  ──▶  Node 2 (NO public IP)
  Private Subnet 10.0.13.0/24  ──▶  Node 3 (NO public IP) [max scale]
```

Internet cannot initiate a connection to your nodes. Period.
Not even if someone somehow knew the private IP. The route simply does not exist.

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
  │  │  │  PUBLIC SUBNETS                                          │  │  │
  │  │  │  10.0.1.0/24    │   10.0.2.0/24    │   10.0.3.0/24      │  │  │
  │  │  │                                                          │  │  │
  │  │  │  ┌─────────────────────────────────────────────────┐    │  │  │
  │  │  │  │  NAT Gateway (Elastic IP)                        │    │  │  │
  │  │  │  │  Private nodes reach internet through here       │    │  │  │
  │  │  │  │  ~$0.045/hr + data transfer costs               │    │  │  │
  │  │  │  └─────────────────────────────────────────────────┘    │  │  │
  │  │  └─────────────────────────────────────────────────────────┘  │  │
  │  │                              │                                 │  │
  │  │                      outbound only                             │  │
  │  │                              │                                 │  │
  │  │  ┌─────────────────────────────────────────────────────────┐  │  │
  │  │  │  PRIVATE SUBNETS (nodes AND bastion live here)           │  │  │
  │  │  │  10.0.11.0/24  │  10.0.12.0/24  │  10.0.13.0/24        │  │  │
  │  │  │                                                          │  │  │
  │  │  │  ┌──────────────┐  ┌──────────────┐                     │  │  │
  │  │  │  │ Node 1       │  │ Node 2       │                     │  │  │
  │  │  │  │ t3.medium    │  │ t3.medium    │                     │  │  │
  │  │  │  │ NO public IP │  │ NO public IP │                     │  │  │
  │  │  │  │              │  │              │                     │  │  │
  │  │  │  │ Pods running:│  │ Pods running:│                     │  │  │
  │  │  │  │ - ums-app    │  │ - ums-app    │                     │  │  │
  │  │  │  │ - postgres   │  │ - coredns    │                     │  │  │
  │  │  │  │   (+ EBS)    │  │ - ebs-csi   │                     │  │  │
  │  │  │  └──────────────┘  └──────────────┘                     │  │  │
  │  │  │                                                          │  │  │
  │  │  │  ┌────────────────────────────────────────────────────┐  │  │  │
  │  │  │  │  Bastion EC2 (t3.micro)                            │  │  │  │
  │  │  │  │  No public IP. Egress 443 only. SSM access only.   │  │  │  │
  │  │  │  │  kubectl + kubeconfig configured at boot           │  │  │  │
  │  │  │  │  eks-repo cloned at ~/eks-repo                     │  │  │  │
  │  │  │  └────────────────────────────────────────────────────┘  │  │  │
  │  │  └─────────────────────────────────────────────────────────┘  │  │
  │  │                                                                │  │
  │  │  ┌─────────────────────────────────────────────────────────┐  │  │
  │  │  │  DATABASE SUBNETS (reserved, not used here)              │  │  │
  │  │  │  10.0.21.0/24  │  10.0.22.0/24  │  10.0.23.0/24        │  │  │
  │  │  └─────────────────────────────────────────────────────────┘  │  │
  │  │                                                                │  │
  │  │  ┌──────────────────────────────────────┐                     │  │
  │  │  │  EKS Control Plane (AWS-managed)     │                     │  │
  │  │  │  Endpoint: public + private          │                     │  │
  │  │  │  PrivateLink ENI in private subnet   │                     │  │
  │  │  │  Nodes reach API via private ENI     │                     │  │
  │  │  └──────────────────────────────────────┘                     │  │
  │  │                                                                │  │
  │  │  ┌──────────────────────────────────────┐                     │  │
  │  │  │  EBS Volume (gp3, 5GB, encrypted)    │                     │  │
  │  │  │  Attached to node running postgres   │                     │  │
  │  │  └──────────────────────────────────────┘                     │  │
  │  └────────────────────────────────────────────────────────────────┘  │
  └──────────────────────────────────────────────────────────────────────┘
```

---

## Network Traffic Flow — Every Path Explained

Understanding traffic flow is non-negotiable for a DevOps engineer.

```
  PATH 1 — User → UMS App (inbound)
  ──────────────────────────────────────────────────────────────────
  Internet → AWS NLB (public, created by LoadBalancer Service)
           → ums-app pod on private node (port 8080)

  The NLB has a public IP. The node does NOT. The NLB proxies traffic
  into the VPC to the node's private IP. This is how internet-facing
  apps work with private nodes — the load balancer is public,
  the nodes are private.

  PATH 2 — Node → Internet (outbound, e.g. ECR image pull)
  ──────────────────────────────────────────────────────────────────
  Private Node → Private Route Table → NAT Gateway (public subnet)
              → Internet Gateway → ECR / AWS APIs / DockerHub

  PATH 3 — Pod → Kubernetes API (inbound to control plane)
  ──────────────────────────────────────────────────────────────────
  Pod on private node → PrivateLink ENI (in private subnet)
                      → EKS Control Plane

  No NAT needed. The PrivateLink ENI lives IN the private subnet.
  kubectl get pods, service account tokens, all of it goes this way.

  PATH 4 — Bastion → Kubernetes API
  ──────────────────────────────────────────────────────────────────
  Bastion (private subnet) → PrivateLink ENI (same private subnet)
                           → EKS API Server

  PATH 5 — Your Laptop → Bastion (SSM)
  ──────────────────────────────────────────────────────────────────
  Laptop → AWS SSM Service endpoint (public AWS API)
         → SSM Agent on bastion (outbound 443 from bastion)
         → Encrypted tunnel established

  The bastion only has OUTBOUND rules. It calls OUT to SSM.
  You ride that outbound connection IN. No inbound ports needed.
```

---

## Kubernetes Workloads

```
  Namespace: ums-app
  ──────────────────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────────────────────┐
  │  STORAGE LAYER                                              │
  │                                                             │
  │  StorageClass: ebs-gp3-sc                                   │
  │    provisioner: ebs.csi.aws.com                             │
  │    WaitForFirstConsumer ← creates EBS in correct AZ         │
  │    Retain ← EBS outlives the PVC if deleted                 │
  │    encrypted: "true" ← gp3 at rest encryption               │
  │                    │                                        │
  │                    ▼ claimed by                             │
  │  PVC: postgres-pvc (5Gi, ReadWriteOnce)                     │
  │    status: Pending until postgres pod is scheduled          │
  │    then: Bound to an EBS volume in the pod's AZ             │
  └─────────────────────────────────────────────────────────────┘
                         │
                         ▼ mounted into
  ┌─────────────────────────────────────────────────────────────┐
  │  DATABASE LAYER                                             │
  │                                                             │
  │  postgres Deployment (1 replica, private node)             │
  │  ┌─────────────────────────────────────────────────────┐   │
  │  │  Container: postgres:16-alpine                       │   │
  │  │  Env: POSTGRES_DB=umsdb  (from Secret)              │   │
  │  │       POSTGRES_USER=umsuser                         │   │
  │  │       POSTGRES_PASSWORD=umspassword                 │   │
  │  │  Volume: /var/lib/postgresql/data ← EBS mounted here│   │
  │  │  readinessProbe: pg_isready -U umsuser -d umsdb     │   │
  │  └─────────────────────────────────────────────────────┘   │
  │                                                             │
  │  Service: postgres-svc  ClusterIP:5432                      │
  │  (internal only, DNS: postgres-svc.ums-app.svc.cluster.local│
  └─────────────────────────────────────────────────────────────┘
                         │
              connects to via ClusterIP DNS
                         │
  ┌─────────────────────────────────────────────────────────────┐
  │  APPLICATION LAYER                                          │
  │                                                             │
  │  ums-app Deployment (2 replicas, spread across nodes)       │
  │  ┌─────────────────────────────────────────────────────┐   │
  │  │  Container: priyeshrai711/ums-app:latest             │   │
  │  │  Port: 8080                                         │   │
  │  │  APP_PROFILE=prod → reads DB_URL from env           │   │
  │  │  DB_URL=jdbc:postgresql://postgres-svc:5432/umsdb   │   │
  │  │  DB_USERNAME from postgres-secret                   │   │
  │  │  DB_PASSWORD from postgres-secret                   │   │
  │  │  readiness: GET /api/users/health (delay 30s)       │   │
  │  │  liveness:  GET /api/users/health (delay 60s)       │   │
  │  └─────────────────────────────────────────────────────┘   │
  │                                                             │
  │  Service: ums-loadbalancer-svc  LoadBalancer:80→8080        │
  │  AWS creates NLB → EXTERNAL-IP = public DNS name           │
  └─────────────────────────────────────────────────────────────┘
```

---

## Private Nodegroup vs Public Nodegroup — Deep Comparison

```
  Aspect               Public Nodegroup          Private Nodegroup
  ───────────────────────────────────────────────────────────────────
  Node subnet          Public (10.0.1-3.x)       Private (10.0.11-13.x)
  Node has public IP   YES                        NO
  Internet → node      POSSIBLE (via IGW)         IMPOSSIBLE
  Node → internet      Direct (via IGW, free)     Via NAT GW ($0.045/hr)
  Attack surface       Larger                     Minimal
  Compliance readiness Dev/learning               PCI-DSS, SOC2, HIPAA
  Debugging ease       Easier                     Harder (need bastion)
  Cost                 Lower                      Higher (NAT Gateway)
  Pod networking       Same                       Same
  App accessibility    Same (via LB)              Same (via LB)
  K8s manifests        Identical                  Identical
  Terraform code diff  1 line (subnet_ids)        1 line (subnet_ids)
```

The NLB that serves your app to the internet is ALWAYS in public subnets
regardless of where nodes are. That's what the subnet discovery tags
(`kubernetes.io/role/elb = 1` on public subnets) are for — they tell the
AWS Load Balancer Controller which subnets to place load balancers in.

---

## Security Posture — Why Prod Uses Private

```
  THREAT MODEL COMPARISON
  ──────────────────────────────────────────────────────────────────

  Scenario: attacker scans your IP space and finds EC2 IPs

  Public nodegroup:
  Attacker finds node IP → tries port 22 → blocked (SG has no SSH rule)
                         → tries port 10250 (kubelet) → blocked (SG)
                         → tries other ports → blocked (SG)
  Result: blocked by SGs. But the attack surface exists.
          One misconfigured SG rule and you have a problem.

  Private nodegroup:
  Attacker finds... nothing. The IPs are RFC-1918 private.
  They are not routable from the internet.
  There is no network path. SGs are a second layer of defence, not first.

  LESSON:
  Security groups are a gate. Private subnets remove the road to the gate.
  Defence-in-depth means both, not either/or.
```

---

## IAM Architecture

```
  ┌──────────────────────────────────────────────────────────────┐
  │  eks-private-dev-cluster-role                                │
  │  Principal: eks.amazonaws.com                                │
  │  Used by: EKS control plane (AWS manages this)              │
  │  Policy: AmazonEKSClusterPolicy                             │
  │          AmazonEKSVPCResourceController                     │
  └──────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────┐
  │  eks-private-dev-node-role                                   │
  │  Principal: ec2.amazonaws.com                                │
  │  Used by: EC2 worker nodes at boot time                      │
  │  Policies:                                                   │
  │    AmazonEKSWorkerNodePolicy   → register with cluster       │
  │    AmazonEKS_CNI_Policy        → assign VPC IPs to pods      │
  │    AmazonEC2ContainerRegistryReadOnly → pull ECR images      │
  │    AmazonSSMManagedInstanceCore → SSM access to nodes        │
  └──────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────┐
  │  eks-private-dev-ebs-csi-role                                │
  │  Principal: pods.eks.amazonaws.com  ← POD IDENTITY           │
  │  Action: sts:AssumeRole + sts:TagSession  ← both required    │
  │  Bound to: kube-system/ebs-csi-controller-sa                 │
  │  Policy: AmazonEBSCSIDriverPolicy                            │
  │                                                              │
  │  Flow:                                                       │
  │  Pod requests creds → pod-identity-agent DaemonSet           │
  │                     → checks association table               │
  │                     → returns scoped IAM token               │
  │                     → EBS CSI calls ec2:CreateVolume etc.    │
  └──────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────┐
  │  eks-private-dev-bastion-ssm-role                            │
  │  Principal: ec2.amazonaws.com (bastion instance)             │
  │  Policies:                                                   │
  │    AmazonSSMManagedInstanceCore → allows SSM sessions        │
  │    Inline: eks:DescribeCluster, eks:ListClusters             │
  │            ec2:Describe* → read-only for debugging           │
  │                                                              │
  │  This role ARN is passed to the EKS access entry →          │
  │  the bastion gets AmazonEKSClusterAdminPolicy on the cluster │
  └──────────────────────────────────────────────────────────────┘
```

---

## Addon Dependency Chain — Why Order Matters

```
  This is the order Terraform must create addons. Each depends on the previous.

  aws_eks_cluster.this
       │
       ├──▶ vpc-cni          (no node needed — control plane uses it)
       ├──▶ kube-proxy        (no node needed)
       │
       ├──▶ aws_eks_node_group.node_group  (nodes must exist first)
                │
                ├──▶ coredns              (needs nodes to schedule on)
                ├──▶ metrics-server       (needs nodes to schedule on)
                │
                └──▶ eks-pod-identity-agent  (DaemonSet — needs nodes)
                           │
                           ▼
                  aws_eks_pod_identity_association.ebs_csi
                  (tells EKS: service account X in namespace Y → role Z)
                           │
                           ▼
                  aws-ebs-csi-driver addon
                  (NOW can assume the role via Pod Identity)
```

If you skip the pod-identity-agent or create the association before the
agent addon exists — the EBS CSI pod will start, try to get AWS credentials,
fail silently, and your PVCs will stay Pending forever.
Not an obvious error. The agent MUST come first.

---

## How to Deploy

```bash
# Step 1 — Provision
cd eks-private-nodegroup/terraform
terraform init
terraform plan
terraform apply     # ~15-20 minutes

# Step 2 — Get outputs
terraform output ssm_connect_command
terraform output configure_kubectl    # for reference

# Step 3 — Connect to bastion via SSM
aws ssm start-session --target <bastion_instance_id> --region ap-south-1

# Step 4 — On bastion: verify cluster access
kubectl get nodes
kubectl get pods -A     # should show system pods running

# Step 5 — Apply application manifests
cd ~/eks-repo/terraform-on-aws-eks/07_EKS_EBS_CSI/04_ebs_csi_addon/eks-private-nodegroup/k8s-manifests
bash apply-all.sh

# Step 6 — Watch postgres come up (it waits for EBS volume creation)
kubectl get pvc -n ums-app -w
# postgres-pvc: Pending → Bound   (this is when EBS volume gets created)
kubectl get pods -n ums-app -w
# postgres-xxx: Pending → ContainerCreating → Running

# Step 7 — Watch UMS app come up
kubectl get pods -n ums-app -w
# ums-app-xxx: Pending → Running (readiness probe takes 30s)

# Step 8 — Get the public endpoint (LB is public even though nodes aren't)
kubectl get svc -n ums-app ums-loadbalancer-svc
# Wait 2-3 min for NLB to provision. EXTERNAL-IP will appear.

# Step 9 — Test
curl http://<EXTERNAL-IP>/api/users/health
curl -X POST http://<EXTERNAL-IP>/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Priyesh Rai","email":"priyesh@demo.com"}'

# Step 10 — Cleanup (always)
kubectl delete namespace ums-app   # removes pods, services
# NOTE: PVC with Retain policy leaves EBS volume alive — delete manually
# in AWS console or: kubectl delete pv <pv-name> then delete in EC2 console
terraform destroy
```

---

## Debugging Cheat Sheet

```
  Problem                          Debug Command
  ──────────────────────────────────────────────────────────────────
  PVC stuck Pending                kubectl describe pvc postgres-pvc -n ums-app
                                   kubectl logs -n kube-system \
                                     -l app=ebs-csi-controller -c csi-provisioner

  Pod stuck Pending                kubectl describe pod <pod> -n ums-app
                                   (look at Events section at the bottom)

  App pods CrashLoopBackOff        kubectl logs <pod> -n ums-app
                                   (Spring Boot stack trace will be there)

  Can't connect to DB              kubectl exec -it <ums-pod> -n ums-app -- \
                                     curl postgres-svc:5432
                                   kubectl get svc -n ums-app postgres-svc

  LB stuck, no EXTERNAL-IP         kubectl describe svc ums-loadbalancer-svc -n ums-app
                                   (check Events — usually IAM or subnet tag issue)

  EBS CSI not working              kubectl get pods -n kube-system | grep ebs
                                   kubectl describe pod <ebs-csi-pod> -n kube-system

  Bastion can't reach cluster      aws eks update-kubeconfig \
                                     --region ap-south-1 --name eks-private-dev
                                   kubectl cluster-info
```

---

## One-Line Difference From Public Nodegroup

```hcl
// PUBLIC nodegroup (eks-public-nodegroup/terraform/modules/eks/main.tf)
resource "aws_eks_node_group" "node_group" {
  subnet_ids = var.public_subnet_ids    // ← nodes in public subnets
  ...
}

// PRIVATE nodegroup (eks-private-nodegroup/terraform/modules/eks/main.tf)
resource "aws_eks_node_group" "node_group" {
  subnet_ids = var.private_subnet_ids   // ← nodes in private subnets
  ...
}
```

One line. The rest of the codebase — VPC, bastion, addons, IAM, manifests —
is identical. That's the point: infrastructure should be composable.
Changing where nodes sit should not require rewriting everything else.
