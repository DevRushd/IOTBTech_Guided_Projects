variable "aws_region" {
  description = "AWS region where the Terraform state bucket is created."
  type        = string
  default     = "us-west-1"
}

variable "project_name" {
  description = "Short project name, used in the bucket name and tags."
  type        = string
  default     = "iotbtech-stack-project"
}
