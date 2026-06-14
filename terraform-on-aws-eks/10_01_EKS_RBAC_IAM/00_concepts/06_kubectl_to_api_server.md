# 06 — How kubectl Actually Reaches the Cluster

No session. No login. Every command re-authenticates. Here's the full chain.

---

## Step 1: kubectl reads kubeconfig, calls STS before touching Kubernetes

```
~/.kube/config
  ├── cluster.server: https://ABC123.gr7.ap-south-1.eks.amazonaws.com
  └── user.exec:
        command: aws
        args: ["eks", "get-token", "--cluster-name", "fintech-prod"]
```

Before any API call, kubectl runs that exec command:

```
aws eks get-token --cluster-name fintech-prod
  │
  └── calls AWS STS internally
        │
        └── creates a PRESIGNED URL for STS:GetCallerIdentity
              │
              │   Presigned URL = regular HTTPS URL with AWS credentials
              │   baked into query params. No separate auth header.
              │   Expires in 15 minutes.
              │
              └── output back to kubectl:
                    {
                      "kind": "ExecCredential",
                      "status": {
                        "token": "k8s-aws-v1.aHR0cHM6Ly9zdHMuYW1hem9u..."
                      }                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^
                    }                          base64-encoded presigned URL
```

kubectl now makes:

```
GET https://ABC123.gr7.ap-south-1.eks.amazonaws.com
    /api/v1/namespaces/backend-prod/pods/payment-service/log

Headers:
  Authorization: Bearer k8s-aws-v1.aHR0cHM6Ly9zdHMuYW1hem9u...
```

---

## Step 2: API server pipeline — every request goes through all 4 stages

```
HTTPS request arrives at EKS API server
         │
         ▼
┌─────────────────────────────────────────────────────┐
│  STAGE 1: AUTHENTICATION (authn)                    │
│                                                     │
│  "Who are you?"                                     │
│                                                     │
│  API server decodes Bearer token → presigned URL    │
│  Calls: GET https://sts.amazonaws.com/?Action=      │
│              GetCallerIdentity&X-Amz-Signature=...  │
│                                                     │
│  STS responds:                                      │
│    Arn: "arn:aws:sts::123:assumed-role/             │
│               eks-backend-dev-role/dave"            │
│                                                     │
│  EKS looks up Access Entry for eks-backend-dev-role │
│    → username: "backend-dev"                        │
│    → groups:   ["eks-backend-devs"]                 │
│                                                     │
│  Result: identity = "backend-dev" in               │
│          group "eks-backend-devs"                   │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  STAGE 2: AUTHORIZATION (authz / RBAC)              │
│                                                     │
│  "Are you ALLOWED to do this?"                      │
│                                                     │
│  verb:      get                                     │
│  resource:  pods/log                                │
│  namespace: backend-prod                            │
│                                                     │
│  RBAC check:                                        │
│    RoleBinding in backend-prod that grants          │
│    group "eks-backend-devs" verb "get"              │
│    on "pods/log"?                                   │
│                                                     │
│    YES → proceed                                    │
│    NO  → 403 Forbidden, stop here                  │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  STAGE 3: ADMISSION CONTROLLERS                     │
│                                                     │
│  "Is what you're doing VALID?"                      │
│                                                     │
│  Matters for create/update — not for reads          │
│  Example: Kyverno blocks image not from ECR         │
│           OPA blocks pod without resource limits    │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  STAGE 4: EXECUTE                                   │
│                                                     │
│  kubectl get pods/deployments  → in-memory cache   │
│  kubectl create/delete         → write to etcd     │
│  kubectl logs                  → kubelet on node   │
│  kubectl exec                  → websocket tunnel  │
└─────────────────────────────────────────────────────┘
```

---

## Step 3: Where data lives — three completely different places

```
                ┌──────────────────────────────────────┐
                │         API SERVER MEMORY            │
                │                                      │
                │   In-memory Watch Cache              │
                │   ┌─────────────────────────────┐   │
                │   │ pods, deployments, services  │   │
                │   │ updated instantly via watch  │   │
                │   └──────────────┬──────────────┘   │
                └──────────────────┼───────────────────┘
                                   │ watch stream (gRPC)
                                   ▼
                ┌──────────────────────────────────────┐
                │               ETCD                   │
                │   /registry/pods/backend-prod/...    │
                │   /registry/secrets/backend-prod/... │
                │   /registry/clusterroles/...         │
                │   (secrets stored encrypted)         │
                └──────────────────────────────────────┘

                ┌──────────────────────────────────────┐
                │         NODE FILESYSTEM              │
                │   /var/log/containers/*.log          │
                │   kubelet reads + streams these      │
                │   NEVER in etcd                      │
                └──────────────────────────────────────┘
```

Rule:
- `kubectl get pods` → in-memory cache (fast, no etcd hit)
- `kubectl create/delete` → etcd (persistent, authoritative)
- `kubectl logs` → node filesystem via kubelet (never etcd)
- `kubectl exec` → websocket tunnel to container via kubelet

---

## Step 4: Token expiry — 15 minutes, silent refresh

```
14:00  kubectl get pods
         → aws eks get-token runs → token valid until 14:15
         → kubectl caches token in memory

14:07  kubectl get deployments
         → token still valid → reused, no STS call

14:16  kubectl get services
         → token expired → aws eks get-token runs again
         → new token, valid until 14:31
         → you never see this happen — completely silent
```

kubeconfig = permanent (until you rotate it)
token      = 15-minute proof-of-identity, silently refreshed

---

## Step 5: exec is different — websocket, not HTTP request-response

```
kubectl exec -it pod/payment-service -- /bin/sh

kubectl ──── HTTP Upgrade ────► API server
                                    │
                                    └── open tunnel ──► kubelet
                                                            │
                                                            └── attach to container

◄──────────────────── bidirectional websocket (stays open) ──────────────────────►

you type: ls -la     ──────────────────────────────────────────────────────────►
container output     ◄──────────────────────────────────────────────────────────
you type: exit       ──── tunnel closes ────
```

**Audit log gap:** EKS audit log records the exec START only. Every command typed inside is invisible to Kubernetes. Falco fills this gap by capturing syscalls on the node.

---

## Full flow: `kubectl logs pod/payment-service -n backend-prod` as Dave

```
bastion (Dave)
  │
  │  kubectl reads kubeconfig
  │  runs: aws eks get-token
  ▼
AWS STS
  │  presigned GetCallerIdentity URL created
  │  encoded as k8s-aws-v1.<base64>
  ▼
EKS API server
  │  AUTHN: calls STS → "assumed-role/eks-backend-dev-role/dave"
  │         Access Entry → username="backend-dev" groups=["eks-backend-devs"]
  │  AUTHZ: RoleBinding in backend-prod: eks-backend-devs has pods/log get? YES
  │  EXECUTE: find pod on node ip-10-0-1-45
  ▼
kubelet on ip-10-0-1-45:10250
  │  opens /var/log/containers/payment-service_backend-prod_xxx.log
  │  streams to API server
  ▼
API server streams to kubectl
  ▼
Dave's terminal prints logs

Simultaneously:
  CloudTrail: GetCallerIdentity called by dave, role=eks-backend-dev-role
  EKS audit:  user=backend-dev, verb=get, pods/log, backend-prod, 200
```
