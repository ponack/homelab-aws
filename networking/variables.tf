variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "homelab"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type = map(object({ cidr = string, az = string }))
  default = {
    a = { cidr = "10.0.1.0/24", az = "us-east-1a" }
    b = { cidr = "10.0.2.0/24", az = "us-east-1b" }
  }
}

variable "private_subnets" {
  type = map(object({ cidr = string, az = string }))
  default = {
    a = { cidr = "10.0.10.0/24", az = "us-east-1a" }
    b = { cidr = "10.0.11.0/24", az = "us-east-1b" }
  }
}
