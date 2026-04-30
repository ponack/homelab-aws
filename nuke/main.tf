terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "local" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "crucible-iap"
      Stack       = "nuke"
    }
  }
}

# Import existing resources created in a prior run whose state was not retained.
import {
  to = aws_iam_role.nuke
  id = "aws-nuke-role"
}

import {
  to = aws_iam_role_policy_attachment.nuke_admin
  id = "aws-nuke-role/arn:aws:iam::aws:policy/AdministratorAccess"
}

data "aws_iam_policy_document" "nuke_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [var.trusted_principal_arn]
    }
  }
}

resource "aws_iam_role" "nuke" {
  name               = "aws-nuke-role"
  assume_role_policy = data.aws_iam_policy_document.nuke_assume_role.json

  tags = { Name = "aws-nuke-role" }
}

resource "aws_iam_role_policy_attachment" "nuke_admin" {
  role       = aws_iam_role.nuke.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
