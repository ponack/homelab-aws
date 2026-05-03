variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "homelab"
}

variable "crucible_stack_slug" {
  type        = string
  description = "Crucible stack slug used in the OIDC sub claim (visible in the stack's URL)."
  default     = "build-infrastructure"
}
