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
      Stack       = "prep"
    }
  }
}

# ── Protected VPC ─────────────────────────────────────────────────────────────
# Tagged crucible-nuke-protect=true so aws-nuke skips all resources here.
# The protected instance lives in this VPC and survives nuke runs.

resource "aws_vpc" "protected" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "nuke-protected-vpc", crucible-nuke-protect = "true" }
}

resource "aws_subnet" "protected" {
  vpc_id            = aws_vpc.protected.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "nuke-protected-subnet", crucible-nuke-protect = "true" }
}

resource "aws_security_group" "protected" {
  name        = "nuke-protected-sg"
  description = "nuke protected instance"
  vpc_id      = aws_vpc.protected.id
  tags        = { crucible-nuke-protect = "true" }
}

resource "aws_instance" "protected" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.protected.id
  vpc_security_group_ids = [aws_security_group.protected.id]

  tags = {
    Name                  = "nuke-test-protected"
    crucible-nuke-protect = "true"
  }
}

# ── Target VPC ────────────────────────────────────────────────────────────────
# No protect tags — everything here gets deleted on a live nuke run.
# Separate VPC ensures the protected instance's ENI never blocks cleanup.

resource "aws_vpc" "target" {
  cidr_block = "10.1.0.0/16"
  tags       = { Name = "nuke-target-vpc" }
}

resource "aws_subnet" "target" {
  vpc_id            = aws_vpc.target.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "nuke-target-subnet" }
}

resource "aws_security_group" "target" {
  name        = "nuke-target-sg"
  description = "nuke target instance"
  vpc_id      = aws_vpc.target.id
}

resource "aws_instance" "target" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.target.id
  vpc_security_group_ids = [aws_security_group.target.id]

  tags = {
    Name = "nuke-test-target"
  }
}

# ── Crucible IAP OIDC runner role ─────────────────────────────────────────────
# Allows the Crucible runner to assume this role via OIDC workload identity.
# Tagged crucible-nuke-protect=true so aws-nuke never deletes it.

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "crucible_runner_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/crucible.forgedinfeatherstechnology.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "crucible.forgedinfeatherstechnology.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "crucible.forgedinfeatherstechnology.com:sub"
      values   = ["stack:*"]
    }
  }
}

import {
  to = aws_iam_role.crucible_runner
  id = "crucible-runner"
}

resource "aws_iam_role" "crucible_runner" {
  name               = "crucible-runner"
  assume_role_policy = data.aws_iam_policy_document.crucible_runner_assume.json
  tags               = { Name = "crucible-runner", crucible-nuke-protect = "true" }
}

import {
  to = aws_iam_role_policy_attachment.crucible_runner_admin
  id = "crucible-runner/arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "crucible_runner_admin" {
  role       = aws_iam_role.crucible_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ── aws-nuke execution role ────────────────────────────────────────────────────
# aws-nuke assumes this role to enumerate and delete resources.
# crucible-runner must be trusted here — it's the identity that runs the nuke job.
# Tagged crucible-nuke-protect=true so it survives nuke runs.

data "aws_iam_policy_document" "aws_nuke_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.crucible_runner.arn]
    }
  }
}

import {
  to = aws_iam_role.aws_nuke
  id = "aws-nuke-role"
}

resource "aws_iam_role" "aws_nuke" {
  name               = "aws-nuke-role"
  assume_role_policy = data.aws_iam_policy_document.aws_nuke_assume.json
  tags               = { Name = "aws-nuke-role", crucible-nuke-protect = "true" }
}

import {
  to = aws_iam_role_policy_attachment.aws_nuke_admin
  id = "aws-nuke-role/arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "aws_nuke_admin" {
  role       = aws_iam_role.aws_nuke.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
