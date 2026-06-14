# 05 — RBAC Hardening

## Problem
RBAC is additive — you can only allow, not explicitly deny. But some permissions are dangerous and should never reach developers. How do production teams prevent privilege escalation?

## Dangerous Permissions — Never Grant to Developers

| Permission | Why dangerous |
|-----------|---------------|
| `pods/exec` | Interactive shell in running pod — reads env vars, mounted secrets |
| `secrets: get/list` | Reads all secret values in namespace |
| `rolebindings: create` | Can grant themselves more permissions |
| `clusterrolebindings: create` | Can grant cluster-admin to themselves |
| `escalate` verb | Can create roles with MORE permissions than they have |
| `bind` verb | Can bind any role to any subject |
| `impersonate` verb | Can act as any user/group/SA in the cluster |

## Hardening Patterns

**1. Block exec at Role level**
Never include `pods/exec` in developer roles. RBAC additive = if it's not there, it's denied.

**2. Disable default SA token automount**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
automountServiceAccountToken: false  # only enable if pod calls K8s API
```

**3. Namespace labels for Pod Security**
```yaml
kubectl label namespace prod pod-security.kubernetes.io/enforce=restricted
```

**4. No secrets in developer Role verbs**
Developer Role = pods/deployments/services/configmaps/events/logs only.

## Implementation
k8s-manifests:
- 01-disable-sa-token-automount.yaml
- 02-pod-security-namespace-labels.yaml
- 03-hardened-developer-role.yaml

## Revision Notes
- Hardening = NOT granting dangerous permissions. Not a separate system.
- Check every Role you write: does it include bind/escalate/impersonate? It shouldn't.
- Pairs with module 16_EKS_Security_Advanced for full security posture.
