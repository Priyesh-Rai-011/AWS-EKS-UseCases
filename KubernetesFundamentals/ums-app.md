# UMS App on EKS — How Everything Connects

9 files. One app. Here's how they chain together.

---

## File Map — Execution Order

```
00-namespace.yaml
01-storage-class.yaml
03-mysql-secret.yaml
04-mysql-configmap.yaml
05-mysql-statefulset.yaml   depends on → 01, 03  (owns PVC via volumeClaimTemplates)
06-mysql-clusterip-svc.yaml                       (headless — required by StatefulSet)
07-ums-configmap.yaml       references → 06 (uses "mysql-svc" DNS name)
08-ums-deployment.yaml      depends on → 03, 07
09-ums-loadbalancer-svc.yaml
```

> `02-mysql-pvc.yaml` is gone — StatefulSet provisions its own PVC automatically via `volumeClaimTemplates`.

---

## The Storage Chain

StatefulSet handles PVC creation itself. No separate PVC manifest needed.

```
01-storage-class.yaml
─────────────────────
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
                │
                │  referenced by
                ▼
05-mysql-statefulset.yaml
─────────────────────────
volumeClaimTemplates:
  - metadata:
      name: mysql-data
    spec:
      storageClassName: ebs-gp3-sc   ← points to StorageClass above
      accessModes: ReadWriteOnce
      resources.requests.storage: 5Gi

  StatefulSet creates PVC named: mysql-data-mysql-0
                │
                │  EBS CSI Driver → AWS API → vol-0abc (5GB gp3 encrypted)
                ▼
  containers:
    volumeMounts:
      - mountPath: /var/lib/mysql    ← EBS mounted here inside the pod
```

**Why this is better than a standalone PVC:** if you scale to `replicas: 2`,
StatefulSet creates `mysql-data-mysql-0` and `mysql-data-mysql-1` — separate disks,
no two pods ever fight over the same EBS volume.

---

## The Credentials Chain

Both MySQL init and the UMS app pull from the same Secret:

```text
03-mysql-secret.yaml
────────────────────
MYSQL_ROOT_PASSWORD: rootpassword
MYSQL_DATABASE: umsdb
MYSQL_USER: umsuser
MYSQL_PASSWORD: umspassword

         │                              │
         │ envFrom.secretRef            │ env.secretKeyRef (cherry-picks)
         ▼                              ▼
05-mysql-statefulset.yaml       08-ums-deployment.yaml
─────────────────────────       ──────────────────────
gets all 4 keys                 DB_USERNAME ← MYSQL_USER
                                DB_PASSWORD ← MYSQL_PASSWORD
```

---

## The Config Chain — How UMS Finds MySQL

```text
06-mysql-clusterip-svc.yaml         07-ums-configmap.yaml
───────────────────────────         ─────────────────────
metadata.name: mysql-svc      →     DB_URL: jdbc:mysql://mysql-svc:3306/umsdb
clusterIP: None  (headless)                               ↑
                               Kubernetes DNS resolves this to the StatefulSet pod.
                               Headless service gives each pod its own DNS entry:
                               mysql-0.mysql-svc.ums-app.svc.cluster.local

                               08-ums-deployment.yaml
                               ──────────────────────
                               envFrom.configMapRef: ums-config
                               → injects APP_PROFILE=prod and DB_URL into every UMS pod
```

---

## The Traffic Flow — Request to Response

```text
User's Browser
      │
      │  HTTP :80
      ▼
AWS ALB  (created because of 09-ums-loadbalancer-svc.yaml)
      │
      │  annotations:
      │    aws-load-balancer-type: external
      │    aws-load-balancer-scheme: internet-facing
      ▼
09-ums-loadbalancer-svc.yaml
  type: LoadBalancer
  port: 80 → targetPort: 8080
  selector: app=ums-app
      │
      │  routes to pods matching label app=ums-app
      ▼
08-ums-deployment.yaml  (replicas: 2, stateless — safe to scale)
  Pod ums-app-aaa :8080
  Pod ums-app-bbb :8080
      │
      │  DB_URL: jdbc:mysql://mysql-svc:3306/umsdb
      │  (from 07-ums-configmap.yaml)
      ▼
06-mysql-clusterip-svc.yaml
  type: ClusterIP, clusterIP: None  (headless, internal only)
  port: 3306, selector: app=mysql
      │
      │  routes to StatefulSet pod
      ▼
05-mysql-statefulset.yaml  (replicas: 1, stateful)
  Pod mysql-0 :3306
      │
      │  volumeMounts.mountPath: /var/lib/mysql
      ▼
PVC: mysql-data-mysql-0  →  PV  →  AWS EBS vol-0abc (5GB gp3 encrypted)
```

---

## Mental Map — All 9 Files at a Glance

```text
 Namespace: ums-app  (00-namespace.yaml)
 ┌──────────────────────────────────────────────────────────────────────┐
 │                                                                      │
 │  STORAGE                                                             │
 │  01-storage-class.yaml ──→ StatefulSet volumeClaimTemplates         │
 │                             └──→ PVC mysql-data-mysql-0 ──→ EBS vol │
 │                                                                      │
 │  CREDENTIALS                                                         │
 │  03-mysql-secret.yaml ──→ mysql-0 pod (all keys)                    │
 │                      └──→ ums-app pods (MYSQL_USER, MYSQL_PASSWORD) │
 │                                                                      │
 │  CONFIG                                                              │
 │  04-mysql-configmap.yaml  (MySQL init DB name)                       │
 │  07-ums-configmap.yaml ──→ ums-app pods (APP_PROFILE, DB_URL)        │
 │                                                                      │
 │  WORKLOADS                                                           │
 │  05-mysql-statefulset.yaml  ←── Secret + StorageClass               │
 │      serviceName: mysql-svc (must match 06)                         │
 │  08-ums-deployment.yaml     ←── ConfigMap + Secret                  │
 │                                                                      │
 │  NETWORKING                                                          │
 │  06-mysql-clusterip-svc.yaml  clusterIP:None → mysql-0 (headless)  │
 │  09-ums-loadbalancer-svc.yaml             → ums pods (internet ALB) │
 │                                                                      │
 └──────────────────────────────────────────────────────────────────────┘
```

---

## Health Probes — Where They Point

```text
mysql-0 pod
  readinessProbe: exec mysqladmin ping -h localhost   (delay 30s, every 10s, fail×6)
  livenessProbe:  exec mysqladmin ping -h localhost   (delay 60s, every 15s, fail×3)

ums-app pods
  readinessProbe: GET /api/users/health :8080         (delay 30s, every 10s, fail×6)
  livenessProbe:  GET /api/users/health :8080         (delay 60s, every 15s, fail×3)
```

---

## Quick Ops

```bash
# deploy everything
kubectl apply -f k8s-manifests/

# watch pods come up — StatefulSet starts mysql-0, not mysql-<random-hash>
kubectl get pods -n ums-app -w

# StatefulSet auto-created PVC — verify it's bound
kubectl get pvc -n ums-app
# should show: mysql-data-mysql-0   Bound

# get the ALB URL (takes ~2 min to provision)
kubectl get svc ums-loadbalancer-svc -n ums-app

# hit the health endpoint
curl http://<ALB-DNS>/api/users/health

# tail logs
kubectl logs -f mysql-0 -n ums-app
kubectl logs -f -l app=ums-app -n ums-app
```
