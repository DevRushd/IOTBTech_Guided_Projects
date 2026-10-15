output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state. Paste it into environments/dev/backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "backend_hcl_example" {
  description = "Ready-to-copy contents for environments/dev/backend.hcl."
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.state.id}"
    key          = "${var.project_name}/phase1/dev/terraform.tfstate"
    region       = "${var.aws_region}"
    encrypt      = true
    use_lockfile = true
  EOT
}
