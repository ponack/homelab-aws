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

resource "aws_vpc" "nuke_test" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "nuke-test-vpc" }
}

resource "aws_subnet" "nuke_test" {
  vpc_id            = aws_vpc.nuke_test.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "nuke-test-subnet" }
}

resource "aws_security_group" "nuke_test" {
  name        = "nuke-test-sg"
  description = "nuke test instances"
  vpc_id      = aws_vpc.nuke_test.id
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

# This instance is tagged to survive a nuke run
resource "aws_instance" "protected" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.nuke_test.id
  vpc_security_group_ids = [aws_security_group.nuke_test.id]

  tags = {
    Name                  = "nuke-test-protected"
    crucible-nuke-protect = "true"
  }
}

# This instance has no protect tag and will be deleted on a live nuke run
resource "aws_instance" "target" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.nuke_test.id
  vpc_security_group_ids = [aws_security_group.nuke_test.id]

  tags = {
    Name = "nuke-test-target"
  }
}
