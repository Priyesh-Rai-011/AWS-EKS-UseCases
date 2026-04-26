# ==============================================================================
# EBS CSI HELM RELEASE
# Chart: aws-ebs-csi-driver from AWS ECR public gallery
# The serviceAccount annotation injects the IRSA role ARN so the pod can
# call ec2:CreateVolume, ec2:AttachVolume, etc.
# ==============================================================================
resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.38.1"
  namespace  = "kube-system"

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  # Inject IRSA role ARN so the SA can assume the EBS CSI IAM role
  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.ebs_csi_driver_role.arn
  }

  set {
    name  = "node.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  depends_on = [aws_iam_role_policy_attachment.ebs_csi_driver_policy]
}
