# AWS Account Nuke Workflow with Crucible IAP

This guide walks through using [aws-nuke](https://github.com/ekristen/aws-nuke) to clean a sandbox AWS account as part of a Crucible IAP demo or test reset cycle. The approach uses three Crucible stacks — `aws-nuke-env-prep`, `build-infrastructure`, and `aws-nuke-run` — wired together with Crucible's dependency system so the reset loop is a single trigger.

## Overview

```text
aws-nuke-env-prep (one-time setup, locked)

build-infrastructure ──► aws-nuke-run
```

| Stack | What it does |
| ----- | ------------ |
| `aws-nuke-env-prep/` | Creates `aws-nuke-role` in the target account with `AdministratorAccess`. Apply once, then lock the stack in Crucible. |
| `build-infrastructure/` | Creates a protected VPC + EC2 instance (survives nuke) and a target VPC + EC2 instance (gets nuked). Also imports and manages `aws-nuke-role`'s trust policy so `crucible-runner` can assume it. |
| `aws-nuke-run/` | Downloads aws-nuke and runs it against the target account. Downstream of `build-infrastructure`. |

## Prerequisites

- An AWS account to use as the sandbox target (can be the same account Crucible runs in, or a separate target account)
- OIDC federation configured in Crucible so runners can assume IAM roles without static credentials
- A shared `crucible-runner` role in the management/Crucible account that Crucible's OIDC provider can assume (wildcard `sub = stack:*` condition)

## IAM Flow

```text
Crucible runner
  └─ OIDC JWT → crucible-runner role (AdministratorAccess)
       └─ sts:AssumeRole ──► aws-nuke-role (target account)
                                 └─ AdministratorAccess on target account
```

`aws-nuke` always assumes a dedicated role (`--assume-role-arn`) rather than operating as the caller directly. This keeps the nuke permissions isolated and auditable.

`build-infrastructure` manages `aws-nuke-role`'s trust policy (imported into state via `import` blocks), so the trust relationship is version-controlled alongside the rest of the infra.

## Step 1 — Apply `aws-nuke-env-prep/` (once)

Create the Crucible stack pointing at `aws-nuke-env-prep/` in this repo, running **in the target account**.

Set these stack variables:

| Variable | Value |
| -------- | ----- |
| `TF_VAR_account_id` | Your target account ID |
| `TF_VAR_trusted_principal_arn` | ARN of the `crucible-runner` role (e.g. `arn:aws:iam::<account-id>:role/crucible-runner`) |

After the apply succeeds, **lock the stack** in Crucible (Settings → Lock stack). The role only needs to exist once — you don't want it accidentally re-applied or destroyed.

## Step 2 — Apply `build-infrastructure/`

Create the Crucible stack pointing at `build-infrastructure/`. This creates:

- A **protected VPC** (`nuke-protected-vpc`) and EC2 instance tagged `crucible-nuke-protect=true` — survives every nuke run
- A **target VPC** (`nuke-target-vpc`) and EC2 instance with no protect tag — deleted on each nuke run
- Imports `aws-nuke-role` into state and sets its trust policy to allow `crucible-runner` to assume it
- Imports the `crucible-runner` role itself so its config stays under IaC

No variables needed beyond the defaults.

> **Note:** The first apply will show `2 to import` (the `aws-nuke-role` and its `AdministratorAccess` attachment) plus `1 to update` (the trust policy). This is expected.

## Step 3 — Configure `aws-nuke-run/`

Create the Crucible stack pointing at `aws-nuke-run/`, running **in the management account**.

Set these stack variables in Crucible (Environment Variables tab):

| Variable | Example value | Notes |
| -------- | ------------- | ----- |
| `TF_VAR_nuke_role_arn` | `arn:aws:iam::<target-account-id>:role/aws-nuke-role` | Created by `aws-nuke-env-prep/`, trust policy managed by `build-infrastructure/` |
| `TF_VAR_management_account_id` | `<management-account-id>` | Permanently blocklisted — can never be nuked |
| `TF_VAR_dry_run` | `true` | Keep `true` until you've verified the dry-run output |
| `TF_VAR_key_pair_name` | `my-key-pair` | Any key pair to preserve (leave empty to skip) |

Set the **dependency**: go to the Dependencies tab on `aws-nuke-run` and add `build-infrastructure` as an upstream stack.

## Step 4 — Dry run

Trigger `aws-nuke-run` with `dry_run=true` (the default). The run output will list every resource that **would** be deleted.

Things to verify in the output:

- `nuke-test-protected` shows `filtered by config` ✓
- `nuke-test-target` shows `would remove` ✓
- All `StackSet-AWSControlTower*` CloudFormation stacks show `filtered by config` ✓
- Your state bucket (`homelab-tfstate`) shows `filtered by config` ✓
- `aws-nuke-role` shows `filtered by config` ✓
- `crucible-runner` (IAMRole) shows `filtered by config` ✓
- `crucible-runner -> AdministratorAccess` (IAMRolePolicyAttachment) shows `filtered by config` ✓

If anything unexpected appears in the `would remove` list, add a filter for it in [aws-nuke-run/nuke-config.yaml.tpl](../aws-nuke-run/nuke-config.yaml.tpl) before proceeding.

> **Important:** `crucible-runner -> AdministratorAccess` must be filtered. If aws-nuke detaches it on the first pass, the role running the job loses its permissions mid-run, causing every subsequent retry to fail with `AccessDenied` and the run to time out after 90 minutes.

## Step 5 — Live run

Change `TF_VAR_dry_run` to `false` in Crucible, then trigger `aws-nuke-run`.

aws-nuke will:

1. **First pass** — trigger EC2 instance termination; VPCs/subnets/SGs will *fail* on this pass because the instances are still terminating. This is expected.
2. **Retry passes** — once instances finish terminating (~2 min), aws-nuke deletes the remaining networking resources cleanly.
3. **Total runtime** — typically 5–10 minutes for a clean run.

Crucible's downstream trigger then automatically re-runs `build-infrastructure`, recreating the test resources so the account is ready for the next demo cycle.

## Reset loop

Once the initial setup is done, the demo reset cycle is:

1. Trigger `aws-nuke-run` (with `dry_run=false`)
2. Wait — `aws-nuke-run` cleans the account, then `build-infrastructure` auto-runs and re-provisions the test resources
3. Demo is ready again

## Customising what gets preserved

Edit [aws-nuke-run/nuke-config.yaml.tpl](../aws-nuke-run/nuke-config.yaml.tpl). The filter section under `accounts` supports exact name matches, regex patterns, and property/tag matching.

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

After editing the template, commit the change and re-run `aws-nuke-run` with `dry_run=true` to verify before going live.

## Why resource-types targets?

Without a `resource-types: targets:` list, aws-nuke scans every AWS service across all configured regions — including hundreds of legacy/deprecated services (OpsWorks, MachineLearning, Timestream, Lex, FMS, CloudSearch) that return 403 or 503 errors. Across six regions this routinely exceeds a 60-minute job timeout before any actual deletion happens.

The targets list in `aws-nuke-run/nuke-config.yaml.tpl` limits scanning to the resource types that can realistically exist in a sandbox account, bringing scan time from >60 minutes to under a minute.

If you add new resource types to your sandbox (e.g. RDS, EKS), add the corresponding type to the targets list so aws-nuke will scan and clean them.

## Excluded resource types

Some resource types are intentionally absent from the targets list:

| Type | Reason |
| ---- | ------ |
| `EC2RouteTable` | Main route tables cannot be deleted independently — removed automatically with their VPC. Including them causes infinite retry loops. |
| `EC2NetworkACL` | Default NACLs cannot be deleted; non-default ones are removed with their VPC. Including them causes spurious retry loops. |
| `EC2NetworkInterface` | Primary ENIs are auto-deleted when their instance terminates. Including them causes in-use retry loops. |
| `EC2Volume` | Root volumes have `delete_on_termination=true` — AWS cleans them up when the instance terminates. |
