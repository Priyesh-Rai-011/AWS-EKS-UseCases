# Things I learned along ht eway
---

## Service account

### why do we need a Service Account for deployment/service to accees the resources outside the cluster and not for the eks and ecr image pulling action?

- for the inter aws service thing : we assign the aws iam role and the policy inside it to the iam role attached to the ec2 instance.
and
- for the java application or any other application running as a pod / container asking for ht eaws service via api call
the iam role for this process is createl before hand and required policy is attached to it before hand.

while writing the manifest files we just pass the iam role arn to the manifest file