# EKS Secrets Management

Your app needs a database password.

That password cannot live in:
- `application.properties` — committed to Git, public forever
- `Deployment YAML` — same problem, different file
- Environment variable hardcoded in the manifest — same problem
- Baked into the container image — worst of all

So where does it go? And how does the pod prove it's allowed to read it?

Those two questions drive everything in this folder.

---

## What production actually requires

Before picking a technology, define what the system must guarantee:

```text
- Secrets must not live in Git
- Pods must not use long-lived AWS credentials
- Access must be auditable by identity
- Rotation must happen without redeployment (ideally)
- Blast radius must be bounded per service
- Terraform state must not contain plaintext values
- Threat model determines whether etcd exposure is acceptable
```

When you define requirements first, the architecture emerges naturally. The three folders below are consequences of these requirements — not arbitrary choices.

---

## The constraint chain

Every architecture here solves the previous one's weakness. That's not coincidence — that's how infrastructure evolves.

```text
Hardcoded in code / YAML
    └── weakness: anyone with Git access has it
            │
            ▼
Kubernetes Native Secret
    └── weakness: lives in etcd, base64 is not encryption,
                  anyone with API access reads it in plain text
            │
            ▼
ESO + AWS Secrets Manager
    └── weakness: source of truth moves outside cluster (good),
                  but ESO still writes a K8s Secret to etcd (still exposed)
            │
            ▼
CSI Driver + ASCP
    └── secret injected directly into pod as tmpfs (RAM),
        never written to etcd, gone when pod dies
```

Each step solves a real problem. Each step introduces a new tradeoff. Understanding the chain is more valuable than memorizing the commands.

---

## Architecture comparison

```text
                       01 — NATIVE K8s        02 — ESO               03 — CSI + ASCP
                       ────────────────        ──────────────────      ───────────────────

Source of truth        etcd                   AWS Secrets Manager     AWS Secrets Manager
Reaches etcd?          YES                    YES                     NO  ✅
Auth to AWS?           N/A                    IRSA                    IRSA
K8s objects            Secret                 SecretStore             SecretProviderClass
                                              ExternalSecret
                                              K8s Secret
Pod consumes via       env var                env var                 file mount (tmpfs)
                                                                      + optional env var
Audit trail            none                   CloudTrail              CloudTrail
Auto-rotation          no                     refreshInterval sync    re-mount on rotation
ConfigMap needed?      YES                    YES                     YES
Terraform managed?     no                     YES (shell only)        YES (shell only)
```

`ConfigMap` still exists in all three approaches. ESO/CSI handles sensitive values (passwords, tokens). ConfigMap handles non-sensitive config (hostnames, ports, feature flags). They are not in competition.

---

## The full architecture flow — side by side

**02 — ESO:**

```text
   AWS Secrets Manager          ESO Controller              etcd                    Pods
   ───────────────────          ──────────────              ────                    ────
                                SecretStore
                                aws-secrets-manager
                                (namespace: pulseauth)
                                        │
                                        │ IRSA JWT → STS → temp creds
                                        │
   eks-secrets-dev/             ExternalSecret              pulseauth-db-secret
     pulseauth/postgres  ──────▶ pulseauth-db-external  ──▶ DB_HOST                ──▶  postgres StatefulSet
                                  -secret                    DB_PORT                      (envFrom)
                                                             DB_NAME
                                                             DB_USER
                                                             DB_PASSWORD

   eks-secrets-dev/             ExternalSecret              pulseauth-redis-secret
     pulseauth/redis     ──────▶ pulseauth-redis-        ──▶ REDIS_HOST             ──▶  redis Deployment
                                  external-secret             REDIS_PORT                   (envFrom)
                                                             REDIS_PASSWORD

   eks-secrets-dev/             ExternalSecret              pulseauth-mail-secret
     pulseauth/mail      ──────▶ pulseauth-mail-         ──▶ MAIL_HOST              ──▶  pulseauth Deployment
                                  external-secret             MAIL_PORT                    (envFrom:
                                                             MAIL_USER                     all 3 secrets)
                                                             MAIL_PASSWORD
                                                             MAIL_SMTP_AUTH
                                                             MAIL_SMTP_TLS
```

**03 — CSI + ASCP:**

```text
   AWS Secrets Manager          CSI Driver + ASCP           Pod filesystem          Pods
   ───────────────────          ─────────────────           ──────────────          ────

                                SecretProviderClass
                                pulseauth-secrets-provider
                                        │
                                        │ IRSA JWT → STS → temp creds
                                        │ (ServiceAccount: pulseauth)
                                        │
   eks-secrets-dev/                     │
     pulseauth/all       ──────▶  jmesPath extracts ──────▶  tmpfs (RAM)
     {                             14 keys                    /mnt/secrets-store/   ──▶  postgres StatefulSet
       DB_HOST,                                               (never hits disk,           redis Deployment
       DB_PORT,                                                gone when pod dies)         pulseauth Deployment
       DB_NAME,                         │                                                  (volumeMount
       DB_USER,                         │ secretObjects:                                    required on
       DB_PASSWORD,                     ▼ (optional sync)                                   all pods)
       REDIS_HOST,              pulseauth-secrets
       REDIS_PORT,              (K8s Secret written          ──────────────────────▶  envFrom: all pods
       REDIS_PASSWORD,           to etcd as side effect
       MAIL_HOST,                of volume mount —
       MAIL_PORT,                no mount = no secret)
       MAIL_USER,
       MAIL_PASSWORD,
       MAIL_SMTP_AUTH,
       MAIL_SMTP_TLS
     }
```

**Key contrast:**

```text
ESO:  3 SM secrets  →  3 ExternalSecrets  →  3 K8s Secrets  →  pods read env vars
CSI:  1 SM secret   →  1 SecretProviderClass  →  tmpfs + optional K8s Secret  →  pods read env vars

Critical CSI rule: volume mount IS the trigger.
No mount on pod = ASCP never fetches = pulseauth-secrets never created = pod crashes.
```

---

## A note on StorageClass vs SecretProviderClass

These names look similar. They are completely unrelated.

```text
StorageClass         →  PersistentVolumeClaim  →  EBS/EFS volume  →  pod disk (07_EKS_EBS_CSI)
SecretProviderClass  →  CSI volume mount       →  tmpfs (RAM)     →  pod filesystem (03_csi_driver_ascp)
```

Different drivers. Different purpose. Do not confuse them.

---

## Decision matrix — which architecture for which situation

```text
Situation                                           Use
──────────────────────────────────────────────────  ───────────────────
Learning / dev / non-sensitive config               01 Native K8s Secret
Production app, team wants centralized secrets      02 ESO + SM
Production app, compliance requires no etcd trace   03 CSI + ASCP
PCI-DSS / HIPAA / SOC2 environment                  03 CSI + ASCP
App needs env vars, not file mounts                 02 ESO (simpler)
Secret rotation must be transparent to app          03 CSI (re-mounts automatically)
Debugging secrets issues quickly                    02 ESO (richer tooling)
```

---

## What's in this folder

```text
09_EKS_Secrets_Management/
├── README.md                          ← you are here
│
├── 01_native_k8s_secrets/             ← What Kubernetes gives you out of the box
│   ├── terraform/                        and exactly where it breaks
│   └── README.md
│
├── 02_external_secrets_operator/      ← Moving source of truth to AWS Secrets Manager
│   ├── terraform/                        ESO syncs it into K8s. etcd still involved.
│   ├── k8s-manifests/
│   ├── deployment-steps.md
│   └── README.md
│
├── 03_csi_driver_ascp/                ← Eliminating etcd entirely.
│   ├── terraform/                        Secret lives in RAM. Never touches disk.
│   ├── k8s-manifests/
│   └── README.md
│
└── pulseauth/                         ← The application (Spring Boot + Angular)
    └── docker-compose.yml                used across all three approaches
```

Pure K8s concepts (what a Secret is, etcd, RBAC, env vs volume mount) →
[`KubernetesFundamentals/secrets.md`](../../KubernetesFundamentals/secrets.md)

---

Start here → [`01_native_k8s_secrets/`](./01_native_k8s_secrets/)
