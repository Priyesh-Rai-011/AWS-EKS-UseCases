# IRSA vs Pod Identity — How UMS App Gets AWS Credentials

Both mechanisms solve the same problem: give a Kubernetes pod temporary AWS credentials without embedding keys anywhere. The difference is *how* the trust is established and *where* the wiring lives.

---

## The Core Difference

```text
IRSA (old way)                          Pod Identity (new way)
──────────────────────────────────────  ──────────────────────────────────────
Trust lives in the IAM role             Trust lives in an EKS association
  → role trust policy says:               → aws_eks_pod_identity_association says:
    "if token is from OIDC issuer X,        "if pod runs as ums-app-sa in
     and sub = system:serviceaccount:        ums-app namespace in cluster Y,
     ums-app:ums-app-sa"                     give it this role"

ServiceAccount annotation required      No annotation on ServiceAccount
  eks.amazonaws.com/role-arn: <arn>       (SA is just a SA)

OIDC provider must be registered        No OIDC setup needed
  in IAM (per cluster)                    (agent addon does it internally)

Token projected into pod as a file      Agent intercepts credentials endpoint
  and exchanged with STS directly         (169.254.170.23) on the node
```

---

## What Changes in Terraform

| What | IRSA (04_01) | Pod Identity (04_ebs_csi_addon) |
|---|---|---|
| OIDC provider | `aws_iam_openid_connect_provider` created | Not needed |
| Role trust policy | `Principal: Federated: <oidc_arn>` + `sts:AssumeRoleWithWebIdentity` + sub/aud conditions | `Principal: Service: pods.eks.amazonaws.com` + `sts:AssumeRole` + `sts:TagSession` |
| EKS addon | No `eks-pod-identity-agent` addon | `aws_eks_addon.pod_identity_agent` required |
| SA↔Role wiring | Nothing in Terraform — done via SA annotation in k8s manifest | `aws_eks_pod_identity_association` resource |
| EBS CSI addon | `service_account_role_arn` field on the addon | `aws_eks_pod_identity_association.ebs_csi` |

---

## What Changes in k8s Manifests

**IRSA — `02-ums-serviceaccount.yaml` needs the annotation:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ums-app-sa
  namespace: ums-app
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/eks-irsa-dev-ums-app-role
```

**Pod Identity — no annotation, SA is plain:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ums-app-sa
  namespace: ums-app
```

---

## How the Token Flow Works

### IRSA

```text
1. Pod starts with ums-app-sa
2. kubelet mounts a projected OIDC token at /var/run/secrets/eks.amazonaws.com/serviceaccount/token
3. AWS SDK in the pod reads the token (via AWS_WEB_IDENTITY_TOKEN_FILE env var)
4. SDK calls STS AssumeRoleWithWebIdentity — passes the token
5. STS validates token signature against the OIDC provider registered in IAM
6. STS checks sub = system:serviceaccount:ums-app:ums-app-sa in the trust policy
7. STS returns temporary credentials
```

### Pod Identity

```text
1. Pod starts with ums-app-sa
2. AWS SDK calls the Instance Metadata endpoint: http://169.254.170.23/v1/credentials
3. eks-pod-identity-agent (DaemonSet on every node) intercepts the request
4. Agent looks up the association: "this SA in this namespace in this cluster → this role"
5. Agent calls STS on behalf of the pod
6. Returns temporary credentials to the pod
```

---

## Which to Use

| Situation | Recommendation |
|---|---|
| New cluster, EKS 1.24+ | Pod Identity — simpler, no OIDC setup, no SA annotation to manage |
| Cross-account role assumption | IRSA — Pod Identity cross-account support is limited |
| Non-EKS OIDC consumers (e.g., EC2, other clusters) | IRSA — OIDC provider is reusable |
| Migrating from kube2iam / kiam | IRSA — closest mental model |
| You want wiring in one place (Terraform) | Pod Identity — association is a Terraform resource, not a k8s annotation |

For greenfield EKS projects **Pod Identity is the recommended default** as of 2024. IRSA remains fully supported and is the right choice for cross-account scenarios.

---

## UMS Project Directory Map

```text
07_EKS_EBS_CSI/
├── 03_ebs_csi_helm/          — EBS CSI via Helm chart, no Secrets Manager
├── 04_ebs_csi_addon/         — EBS CSI via EKS addon + Pod Identity + ESO
│   ├── eks-public-nodegroup/
│   └── eks-private-nodegroup/
├── 04_01_irsa_vs_podidentity/ — Same stack as 04 but IRSA instead of Pod Identity
│   └── eks-public-nodegroup/
└── 05_comparison/
    └── readme2.md             ← you are here
```

The only functional difference between `04_ebs_csi_addon` and `04_01_irsa_vs_podidentity` is the credential delivery mechanism for the `ums-app-sa` ServiceAccount. Everything else (StorageClass, StatefulSet, ESO, Flyway, app image) is identical.
