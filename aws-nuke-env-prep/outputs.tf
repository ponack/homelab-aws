output "nuke_role_arn" {
  value       = aws_iam_role.nuke.arn
  description = "ARN of the IAM role aws-nuke assumes when running"
}
