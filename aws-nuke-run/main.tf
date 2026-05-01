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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
  backend "local" {}
}

provider "aws" {
  region = var.region
}

provider "null" {}
provider "local" {}

locals {
  # Derive target account ID from the role ARN so it doesn't need to be a
  # separate variable and can't get out of sync.
  target_account_id = regex("arn:aws:iam::([0-9]+):role/", var.nuke_role_arn)[0]
}

# Render the nuke config template with account IDs injected at plan time.
# The rendered file is written into the runner workspace — it is never committed to git.
resource "local_file" "nuke_config" {
  content = templatefile("${path.module}/nuke-config.yaml.tpl", {
    management_account_id = var.management_account_id
    target_account_id     = local.target_account_id
    key_pair_name         = var.key_pair_name
  })
  filename = "${path.module}/.nuke-config-rendered.yaml"
}

resource "null_resource" "aws_nuke" {
  # timestamp() changes every plan → always shows a diff → forces explicit confirmation before every run
  triggers = {
    always_run = timestamp()
  }

  depends_on = [local_file.nuke_config]

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

      # aws-nuke v3: dry-run is the default; --no-dry-run enables live deletion.
      if [ "${var.dry_run}" = "true" ]; then
        echo "DRY RUN — no resources will be deleted"
        "$NUKE_BIN" run \
          --config "${path.module}/.nuke-config-rendered.yaml" \
          --assume-role-arn "${var.nuke_role_arn}" \
          --no-alias-check \
          --no-prompt
      else
        echo "LIVE RUN — resources WILL be deleted in account ${local.target_account_id}"
        "$NUKE_BIN" run \
          --config "${path.module}/.nuke-config-rendered.yaml" \
          --assume-role-arn "${var.nuke_role_arn}" \
          --no-alias-check \
          --no-prompt \
          --no-dry-run
      fi
    EOT
  }
}
