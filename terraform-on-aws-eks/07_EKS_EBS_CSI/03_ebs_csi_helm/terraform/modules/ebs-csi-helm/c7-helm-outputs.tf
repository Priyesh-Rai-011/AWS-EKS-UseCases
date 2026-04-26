output "helm_release_status" {
  description = "Helm release deployment status"
  value       = helm_release.ebs_csi_driver.status
}

output "helm_release_version" {
  description = "Deployed chart version"
  value       = helm_release.ebs_csi_driver.version
}
