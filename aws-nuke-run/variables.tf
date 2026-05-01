variable "region" {
  type    = string
  default = "us-east-1"
}

variable "dry_run" {
  type        = string
  description = "When 'true', aws-nuke scans and reports but does not delete anything. Set 'false' to actually destroy resources."
  default     = "true"
}

variable "aws_nuke_version" {
  type        = string
  description = "ekristen/aws-nuke release tag to download"
  default     = "3.37.0"
}

variable "nuke_role_arn" {
  type        = string
  description = "ARN of the aws-nuke-role in the target account (e.g. arn:aws:iam::<target-account-id>:role/aws-nuke-role)"
}

variable "management_account_id" {
  type        = string
  description = "AWS account ID of the management/Crucible account — permanently blocklisted so it can never be nuked"
}

variable "key_pair_name" {
  type        = string
  description = "EC2 key pair name to preserve from nuke (leave empty to skip)"
  default     = ""
}
