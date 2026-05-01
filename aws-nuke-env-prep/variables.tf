variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "homelab"
}

variable "account_id" {
  type        = string
  description = "Target account ID where aws-nuke-role is created (e.g. 123456789012)"
}

variable "trusted_principal_arn" {
  type        = string
  description = "IAM role ARN in the management account allowed to assume aws-nuke-role (e.g. arn:aws:iam::<management-account-id>:role/crucible-nuke-run)"
}
