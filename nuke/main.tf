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

# crucible-prep is the Crucible IAP runner role for the prep stack.
# Grant EC2 full access so it can create the nuke test VPC + instances.
data "aws_iam_role" "crucible_prep" {
  name = "crucible-prep"
}

resource "aws_iam_role_policy_attachment" "crucible_prep_ec2" {
  role       = data.aws_iam_role.crucible_prep.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
