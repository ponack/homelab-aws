# homelab-aws

AWS homelab infrastructure managed with OpenTofu via [Crucible IAP](https://github.com/ponack/crucible-iap).

## Accounts

| Account | Role |
| ------- | ---- |
| Management | Runs Crucible IAP and the nuke-run runner |
| Target | All resources; receives aws-nuke |

## Stacks

| Stack | Account | Description | Depends On |
| ----- | ------- | ----------- | ---------- |
| `networking/` | target | VPC, subnets, security groups, NAT gateway | — |
| `compute/` | target | EKS cluster, node groups, IAM roles | `networking` |
| `applications/` | target | Helm releases, ingress, cert-manager | `compute` |
| `nuke/` | target | Creates `aws-nuke-role` IAM role (apply once, then lock) | — |
| `prep/` | target | Two test EC2s — one protected, one to be nuked | — |
| `nuke-run/` | management | Runs aws-nuke against the target account — **destructive** | `nuke` |

## Dependency Graph

```text
networking ──► compute ──► applications

nuke (locked after first apply)

prep ──► nuke-run
```

Crucible IAP automatically triggers downstream stacks after a successful apply upstream.

## Usage

Each stack is a separate Crucible IAP stack. Configure them in order and set up
the downstream relationships via the Dependencies tab on each stack.

## Nuking the account

See the full guide: [docs/nuke-workflow.md](docs/nuke-workflow.md)

### Quick reference — stack variables (nuke-run in Crucible)

| Variable | Notes |
| -------- | ----- |
| `TF_VAR_dry_run` | `true` by default — set `false` only when ready to destroy |
| `TF_VAR_nuke_role_arn` | ARN of `aws-nuke-role` in the target account |
| `TF_VAR_management_account_id` | Account ID of your management account (blocklisted from nuke) |
| `TF_VAR_key_pair_name` | EC2 key pair to preserve (leave empty to skip) |

**Filters** — edit [nuke-run/nuke-config.yaml.tpl](nuke-run/nuke-config.yaml.tpl) to protect additional resources before running live.
