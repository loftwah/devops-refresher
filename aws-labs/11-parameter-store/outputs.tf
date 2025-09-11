output "ssm_path_prefix" {
  description = "SSM path used for non-secret params"
  value       = "/devops-refresher/${var.env}/${var.service}"
}

