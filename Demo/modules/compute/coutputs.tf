output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "jenkins_private_ip" {
  value = aws_instance.jenkins.private_ip
}

output "control_plane_ip" {
  value = aws_instance.k3s_master.private_ip
}

# Returns list of IDs for the NLB to attach to
output "worker_ids" {
  value = [
    aws_instance.k3s_worker.id,
    aws_instance.monitoring.id
  ]
}

output "worker_ips" {
  value = [
    aws_instance.k3s_worker.private_ip,
    aws_instance.monitoring.private_ip
  ]
}