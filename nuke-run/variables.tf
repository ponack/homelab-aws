variable "region" {
  type    = string
  default = "us-east-1"
}

variable "dry_run" {
  type        = bool
  description = "When true, aws-nuke scans and reports but does not delete anything. Set false to actually destroy resources."
  default     = true
}

variable "aws_nuke_version" {
  type        = string
  description = "ekristen/aws-nuke release tag to download"
  default     = "3.37.0"
}

variable "nuke_role_arn" {
  type        = string
  description = "ARN of the aws-nuke-role in the TARGET account (767398073332)"
  default     = "arn:aws:iam::767398073332:role/aws-nuke-role"
}
