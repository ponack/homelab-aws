terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
  backend "local" {}
}

provider "aws" {
  region = var.region
}

provider "null" {}

resource "null_resource" "aws_nuke" {
  # timestamp() changes every plan → always shows a diff → forces explicit confirmation before every run
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail

      NUKE_BIN="/tmp/aws-nuke-${var.aws_nuke_version}"

      if [ ! -f "$NUKE_BIN" ]; then
        echo "Downloading aws-nuke v${var.aws_nuke_version}..."
        curl -sSL \
          "https://github.com/ekristen/aws-nuke/releases/download/v${var.aws_nuke_version}/aws-nuke-v${var.aws_nuke_version}-linux-amd64.tar.gz" \
          | tar -xz -C /tmp aws-nuke
        mv /tmp/aws-nuke "$NUKE_BIN"
        chmod +x "$NUKE_BIN"
      fi

      DRY_RUN_FLAG=""
      if [ "${var.dry_run}" = "true" ]; then
        DRY_RUN_FLAG="--dry-run"
        echo "DRY RUN — no resources will be deleted"
      else
        echo "LIVE RUN — resources WILL be deleted in account 303880639739"
      fi

      "$NUKE_BIN" run \
        --config "${path.module}/nuke-config.yaml" \
        --assume-role-arn "${var.nuke_role_arn}" \
        --no-prompt \
        $DRY_RUN_FLAG
    EOT
  }
}
