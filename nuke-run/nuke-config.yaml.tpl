# Only scan regions where resources are actually deployed.
# Add regions here if your stacks deploy elsewhere.
# global covers IAM, S3 (bucket list), Route53, and other non-regional resources.
regions:
  - us-east-1
  - us-east-2
  - global

# Scan only the resource types that can realistically exist in this sandbox.
# Without this, aws-nuke queries hundreds of legacy/unavailable services
# (OpsWorks, MachineLearning, Timestream, Lex, etc.) causing the run to
# time out after 60 minutes before it does any actual work.
resource-types:
  targets:
    # EC2 / networking
    # EC2Volume excluded — root volumes have delete_on_termination=true so AWS
    # cleans them up when the instance terminates.
    # EC2NetworkInterface excluded — primary ENIs are auto-deleted when their
    # instance terminates; including them causes in-use retry loops.
    - EC2Instance
    - EC2VPC
    - EC2Subnet
    - EC2SecurityGroup
    - EC2InternetGateway
    - EC2RouteTable
    - EC2Address
    - EC2KeyPair
    - EC2DHCPOption
    - EC2NetworkACL
    # IAM
    - IAMRole
    - IAMRolePolicyAttachment
    - IAMInstanceProfile
    - IAMPolicy
    - IAMUser
    - IAMGroup
    - IAMGroupPolicyAttachment
    # S3
    - S3Bucket
    - S3Object
    # Other common sandbox resources
    - CloudFormationStack
    - SSMParameter
    - CloudWatchAlarm
    - CloudWatchLogsLogGroup
    - SecretsManagerSecret
    - SNSTopic
    - SQSQueue
    - LambdaFunction
    - ECSCluster
    - ECSService
    - ECSTaskDefinition

# Management account is permanently blocked — never nuke it.
blocklist:
  - "${management_account_id}"

# Target account is a non-production sandbox — bypass the alias/prod-name check.
bypass-alias-check-accounts:
  - "${target_account_id}"

accounts:
  "${target_account_id}":
    filters:
      # Preserve the role aws-nuke uses (self-preservation)
      IAMRole:
        - "aws-nuke-role"
      IAMRolePolicyAttachment:
        - "aws-nuke-role -> AdministratorAccess"

      # Preserve OpenTofu state bucket and its contents
      S3Bucket:
        - "homelab-tfstate"
      S3Object:
        - property: Bucket
          value: "homelab-tfstate"

      # Preserve EC2 instances and all networking resources tagged to survive the nuke.
      # prep/ puts the protected instance in its own VPC tagged crucible-nuke-protect=true
      # so the protected ENI never blocks deletion of the target VPC.
      EC2Instance:
        - property: tag:crucible-nuke-protect
          value: "true"
      EC2VPC:
        - property: tag:crucible-nuke-protect
          value: "true"
      EC2Subnet:
        - property: tag:crucible-nuke-protect
          value: "true"
      EC2SecurityGroup:
        - property: tag:crucible-nuke-protect
          value: "true"
      EC2InternetGateway:
        - property: tag:crucible-nuke-protect
          value: "true"
      EC2RouteTable:
        - property: tag:crucible-nuke-protect
          value: "true"
      EC2DHCPOption:
        - property: tag:crucible-nuke-protect
          value: "true"
      EC2NetworkACL:
        - property: tag:crucible-nuke-protect
          value: "true"

      # Preserve AWS Control Tower baseline infrastructure deployed by the
      # management account into this enrolled account. Nuking these would
      # break Control Tower governance and require re-enrolling the account.
      CloudFormationStack:
        - type: regex
          value: "StackSet-AWSControlTower.*"
      LambdaFunction:
        - type: regex
          value: "aws-controltower-.*"
      CloudWatchLogsLogGroup:
        - type: regex
          value: "/aws/lambda/aws-controltower-.*"
      SNSTopic:
        - type: regex
          property: TopicARN
          value: ".*:aws-controltower-.*"
%{ if key_pair_name != "" ~}

      # Preserve personal key pairs
      EC2KeyPair:
        - "${key_pair_name}"
%{ endif ~}

      # Preserve Crucible runner roles in the target account (if any)
      # Add crucible-prep, crucible-nuke-setup here if you create them in this account:
      # IAMRole:
      #   - "crucible-nuke-setup"
      #   - "crucible-prep"
