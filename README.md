# homelab-aws

AWS homelab infrastructure managed with OpenTofu via [Crucible IAP](https://github.com/ponack/crucible-iap).

## Accounts

| Account | ID | Role |
| ------- | -- | ---- |
| Management | `303880639739` | Runs Crucible IAP and the nuke-run runner |
| Target | `767398073332` | All resources; receives aws-nuke |

## Stacks

| Stack | Account | Description | Depends On |
| ----- | ------- | ----------- | ---------- |
| `networking/` | target | VPC, subnets, security groups, NAT gateway | — |
| `compute/` | target | EKS cluster, node groups, IAM roles | `networking` |
| `applications/` | target | Helm releases, ingress, cert-manager | `compute` |
| `nuke/` | target | Creates `aws-nuke-role` IAM role (apply once) | — |
| `prep/` | target | Two test EC2s — one protected, one to be nuked | — |
| `nuke-run/` | management | Runs aws-nuke against the target account — **destructive** | `nuke` |

## Dependency Graph

```text
networking ──► compute ──► applications

nuke ──► nuke-run
prep ──► nuke-run  (logical; prep before testing live nuke)
```

Crucible IAP automatically triggers downstream stacks after a successful apply upstream.

## Usage

Each stack is a separate Crucible IAP stack. Configure them in order and set up
the downstream relationships via the Dependencies tab on each stack.

## Nuking the account

### Workflow

1. Apply `nuke/` once to create `aws-nuke-role` in the target account
2. Apply `prep/` to create two test EC2 instances
3. Trigger `nuke-run` with `dry_run=true` (default) — verify the scan output
4. Confirm `nuke-test-protected` appears in the **filtered** list, `nuke-test-target` appears in the **to be deleted** list
5. Trigger `nuke-run` with `dry_run=false` to actually destroy

### Cross-account flow

```text
Crucible runner (303880639739)
  └─ crucible-nuke-run role  (OIDC, management account)
       └─ sts:AssumeRole ──► aws-nuke-role (767398073332)
                                 └─ AdministratorAccess on target account
```

### Protection tag

Resources tagged `crucible-nuke-protect=true` are excluded from deletion. The `prep/` stack applies this tag to `nuke-test-protected`. Add it to any other resource in the target account you want to survive a nuke.

### Stack variables (nuke-run in Crucible)

| Variable | Default | Notes |
| -------- | ------- | ----- |
| `TF_VAR_dry_run` | `true` | Set `false` only when ready to destroy |
| `TF_VAR_nuke_role_arn` | `arn:aws:iam::767398073332:role/aws-nuke-role` | Cross-account nuke role |

**Filters** — edit [nuke-run/nuke-config.yaml](nuke-run/nuke-config.yaml) to protect additional resources before running live.
