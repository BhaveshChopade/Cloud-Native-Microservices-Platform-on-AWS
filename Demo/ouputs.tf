output "bastion_ssh_command" {
  value = "ssh -i robot-shop-key.pem ubuntu@${module.compute.bastion_public_ip}"
}

output "scp_key_command" {
  value = "scp -i robot-shop-key.pem robot-shop-key.pem ubuntu@${module.compute.bastion_public_ip}:/home/ubuntu/"
}

output "jenkins_tunnel_command" {
  value = "ssh -i robot-shop-key.pem -L 8080:${module.compute.jenkins_private_ip}:8080 ubuntu@${module.compute.bastion_public_ip}"
}

output "jenkins_private_ip" {
  description = "Private IP of the Jenkins"
  value       = module.compute.jenkins_private_ip
}

output "k3s_control_plane_ip" {
  description = "Private IP of the Master Node"
  value       = module.compute.control_plane_ip
}

output "k3s_worker_ips" {
  description = "Private IPs of the Worker Nodes"
  value       = module.compute.worker_ips
}

output "k3s_app_url" {
  value = "http://${module.nlb.lb_dns_name}"
}

