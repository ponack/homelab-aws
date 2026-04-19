# homelab-aws

AWS homelab infrastructure managed with OpenTofu via [Crucible IAP](https://github.com/ponack/crucible-iap).

## Stacks

| Stack | Description | Depends On |
|-------|-------------|------------|
| `networking/` | VPC, subnets, security groups, NAT gateway | — |
| `compute/` | EKS cluster, node groups, IAM roles | `networking` |
| `applications/` | Helm releases, ingress, cert-manager | `compute` |

## Dependency Graph

```
networking ──► compute ──► applications
```

Crucible IAP automatically triggers downstream stacks after a successful apply upstream.

## Usage

Each stack is a separate Crucible IAP stack. Configure them in order and set up
the downstream relationships via the Dependencies tab on each stack.
