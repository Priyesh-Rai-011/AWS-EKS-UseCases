# ==============================================================================
# EBS CSI IAM ROLE — assumed by ebs-csi-controller-sa via IRSA
# ==============================================================================
resource "aws_iam_role" "ebs_csi_driver_role" {
  name               = "${var.cluster_name}-ebs-csi-role"
  description        = "Assumed by EBS CSI Driver pod via IRSA to manage EBS volumes"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_trust.json

  tags = merge(var.tags, { Name = "${var.cluster_name}-ebs-csi-role" })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver_role.name
}
