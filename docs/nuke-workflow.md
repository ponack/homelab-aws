# AWS Account Nuke Workflow with Crucible IAP

This guide walks through using [aws-nuke](https://github.com/ekristen/aws-nuke) to clean a sandbox AWS account as part of a Crucible IAP demo or test reset cycle. The approach uses three Crucible stacks — `nuke`, `prep`, and `nuke-run` — wired together with Crucible's dependency system so the reset loop is a single trigger.

## Overview

```text
nuke (one-time setup, locked)

prep ──► nuke-run
```

| Stack | What it does |
| ----- | ------------ |
| `nuke/` | Creates `aws-nuke-role` in the target account with `AdministratorAccess`. Apply once, then lock the stack in Crucible. |
| `prep/` | Creates a VPC and two EC2 instances — one tagged to survive the nuke, one to be deleted. |
| `nuke-run/` | Downloads aws-nuke and runs it against the target account. Downstream of `prep`. |

## Prerequisites

- Two AWS accounts: a **management** account (where Crucible runs) and a **target** account (the sandbox to nuke)
- OIDC federation configured in Crucible for the management account so runners can assume IAM roles without static credentials
- A role in the management account (e.g. `crucible-nuke-run`) that `sts:AssumeRole` trusts can be assumed by the Crucible OIDC provider

## Cross-Account IAM Flow

```text
Crucible runner (management account)
  └─ OIDC JWT → crucible-nuke-run role
       └─ sts:AssumeRole ──► aws-nuke-role (target account)
                                 └─ AdministratorAccess on target account
```

The `nuke/` stack creates `aws-nuke-role` in the target account and configures its trust policy to allow assumption from your management account role. Run it once from a principal that has `iam:CreateRole` and `iam:AttachRolePolicy` in the target account.

## Step 1 — Apply `nuke/` (once)

Create the Crucible stack pointing at `nuke/` in this repo, running **in the target account**.

Set these stack variables:

| Variable | Value |
| -------- | ----- |
| `TF_VAR_account_id` | Your target account ID |
| `TF_VAR_trusted_principal_arn` | ARN of the role in the management account that will assume `aws-nuke-role` (e.g. `arn:aws:iam::<management-account-id>:role/crucible-nuke-run`) |

After the apply succeeds, **lock the stack** in Crucible (Settings → Lock stack). The role only needs to exist — you don't want it re-applied or destroyed accidentally.

## Step 2 — Apply `prep/`

Create the Crucible stack pointing at `prep/`. This creates:

- A VPC and subnet in `us-east-1`
- `nuke-test-protected` — EC2 instance tagged `crucible-nuke-protect=true` (survives the nuke)
- `nuke-test-target` — EC2 instance with no protect tag (gets nuked)

No variables needed beyond the defaults.

## Step 3 — Configure `nuke-run/`

Create the Crucible stack pointing at `nuke-run/`, running **in the management account**.

Set these stack variables in Crucible (Environment Variables tab):

| Variable | Example value | Notes |
| -------- | ------------- | ----- |
| `TF_VAR_nuke_role_arn` | `arn:aws:iam::<target-account-id>:role/aws-nuke-role` | Created by the `nuke/` stack |
| `TF_VAR_management_account_id` | `<management-account-id>` | Permanently blocklisted — can never be nuked |
| `TF_VAR_dry_run` | `true` | Keep true until you've verified the dry-run output |
| `TF_VAR_key_pair_name` | `my-key-pair` | Any key pair to preserve (leave empty to skip) |

Set the **dependency**: go to the Dependencies tab on `nuke-run` and add `prep` as an upstream stack.

## Step 4 — Dry run

Trigger `nuke-run` with `dry_run=true` (the default). The run output will list every resource that **would** be deleted.

Things to verify in the output:

- `nuke-test-protected` shows `filtered by config` ✓
- `nuke-test-target` shows `would remove` ✓
- All `StackSet-AWSControlTower*` CloudFormation stacks show `filtered by config` ✓
- Your state bucket shows `filtered by config` ✓
- `aws-nuke-role` shows `filtered by config` ✓

If anything unexpected appears in the `would remove` list, add a filter for it in [nuke-config.yaml.tpl](../nuke-run/nuke-config.yaml.tpl) before proceeding.

## Step 5 — Live run

Change `TF_VAR_dry_run` to `false` in Crucible, then trigger `nuke-run`.

aws-nuke will delete everything in the target account that isn't filtered, then Crucible's downstream trigger automatically re-runs `prep` — so the test resources are recreated and the account is ready for the next demo cycle without any manual steps.

## Reset loop

Once the initial setup is done, the demo reset cycle is:

1. Trigger `nuke-run` (with `dry_run=false`)
2. Wait — `nuke-run` cleans the account, then `prep` auto-runs and re-provisions the test resources
3. Demo is ready again

## Customising what gets preserved

Edit [nuke-run/nuke-config.yaml.tpl](../nuke-run/nuke-config.yaml.tpl). The filter section under `accounts` supports exact name matches, regex patterns, and property/tag matching.

Common additions:

```yaml
# Preserve an RDS instance by tag
RDSInstance:
  - property: tag:keep
    value: "true"

# Preserve all secrets with a name prefix (use glob, not regex — more reliable in v3)
SecretsManagerSecret:
  - type: glob
    value: "prod/*"

# Preserve a specific S3 bucket
S3Bucket:
  - "my-important-bucket"
S3Object:
  - property: Bucket
    value: "my-important-bucket"
```

After editing the template, commit the change and re-run `nuke-run` with `dry_run=true` to verify before going live.

## Why resource-types targets?

Without a `resource-types: targets:` list, aws-nuke scans every AWS service across all configured regions — including hundreds of legacy/deprecated services (OpsWorks, MachineLearning, Timestream, Lex, FMS, CloudSearch) that return 403 or 503 errors. Across six regions this routinely exceeds a 60-minute job timeout before any actual deletion happens.

The targets list in `nuke-config.yaml.tpl` limits scanning to the resource types that can realistically exist in a sandbox account, bringing scan time from >60 minutes to under a minute.

If you add new resource types to your sandbox (e.g. RDS, EKS), add the corresponding type to the targets list so aws-nuke will scan and clean them.
