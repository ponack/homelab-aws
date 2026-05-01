output "protected_instance_id" {
  value       = aws_instance.protected.id
  description = "Instance tagged to survive nuke (crucible-nuke-protect=true)"
}

output "target_instance_id" {
  value       = aws_instance.target.id
  description = "Instance with no protect tag — will be nuked on a live run"
}
