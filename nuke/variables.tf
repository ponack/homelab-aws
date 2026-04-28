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
  description = "Target account ID where aws-nuke-role is created"
  default     = "767398073332"
}

variable "trusted_principal_arn" {
  type        = string
  description = "IAM role ARN (in the management account) allowed to assume aws-nuke-role"
  default     = "arn:aws:iam::303880639739:role/crucible-nuke-run"
}
