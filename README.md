################################################################################################ Project Overview: #################################################################################################

This project implements a production-grade, cloud-native infrastructure on AWS to host the Google Online Boutique, a polyglot microservices application. The primary goal was to move away from managed services (like EKS) to build a custom, cost-optimized K3s Kubernetes cluster from scratch.

The infrastructure follows GitOps principles for deployment and DevSecOps practices for continuous integration. It features a strict network security posture with a custom VPC, private subnets for compute workloads, and a dedicated Bastion host acting as the single point of entry.

------------------------------------------------------------------------------------------------Architecture Highlights:--------------------------------------------------------------------------------------------
1.Orchestration: Self-managed K3s cluster (Lightweight Kubernetes) on AWS EC2.

2.Infrastructure as Code: Terraform for provisioning VPC, Subnets, Gateways, and Compute instances.

3.Network Security: All application and build servers (Jenkins) reside in Private Subnets with no direct internet access.

4.GitOps: ArgoCD manages the continuous delivery, ensuring the cluster state mirrors the Git repository.

5.Observability: Full PLG Stack (Prometheus, Loki, Grafana) for centralized logging and metrics.


-------------------------------------------------------------------------------------------Technology Stack:---------------------------------------------------------------------------------------------------------
Cloud Provider	  =AWS (EC2, VPC, NLB, NAT Gateway)
IaC	              =Terraform
Orchestration	    =K3s (Kubernetes)
CI / Build	      =Jenkins (Private Node)
CD / GitOps	      =ArgoCD
Security	        =SonarCloud (SAST), Trivy (Container & FS Scanning)
Monitoring	      =Prometheus, Loki, Grafana, Promtail
Ingress	          =Traefik
Proxy	            =Nginx (Bastion Host for webhook)

-----------------------------------------------------------------------------------Infrastructure Implementation:---------------------------------------------------------------------------------------------------

A. Network Topology (AWS VPC) :

1.We designed a custom VPC (10.0.0.0/16) segmented into Public and Private zones:
2.Public Subnet: Hosts the NAT Gateway, AWS Network Load Balancer (NLB), and the Bastion Host.
3.Private Subnet: Hosts the K3s Control Plane, Worker Nodes, and the Jenkins Server.
4.Traffic Flow: External traffic hits the NLB (Layer 4), which forwards requests to the Traefik Ingress Controller on the private worker nodes.


B. Secure Webhook Proxy (Bastion Configuration) :

1.Since the Jenkins server is isolated in a private subnet, it cannot receive direct webhook events from GitHub. To solve this without exposing Jenkins to the public internet:
2.Reverse Proxy: We installed and configured Nginx on the Bastion Host (t3.micro).
3.Traffic Routing: Nginx listens on Port 80 and forwards specific payload traffic from GitHub (/github-webhook/) to the private Jenkins instance on Port 8080.
4.Security Groups: The Bastion Security Group was modified to allow Inbound HTTP (Port 80) traffic, strictly for webhook payload delivery.


C. K3s Cluster Setup :

1.We opted for K3s for its reduced resource footprint.
2.Provisioning: EC2 instances (m7i-flex.large) were provisioned via Terraform.
3.Cluster Bootstrapping: The K3s Master was initialized first. Worker nodes were joined manually by generating the node token on the master and executing the join command on the workers. This provided granular control over the joining process during the setup phase.


-------------------------------------------------------------------------------CI/CD Pipeline (DevSecOps & GitOps)--------------------------------------------------------------------------------------------------

A.Continuous Integration (Jenkins) :

1.The CI pipeline is triggered via the Nginx proxy webhook. It executes the following stages:
2.Checkout: Pulls code from the GitHub repository.
3.Static Analysis: Runs SonarCloud to detect code quality issues and bugs.
4.Security Scan: Uses Trivy to scan the filesystem for dependencies vulnerabilities.
5.Build: Creates the Docker image.
6.Image Scan: Trivy scans the final Docker image for OS-level CVEs.
7.Push: Pushes the safe artifact to DockerHub.
#Manifest Update: Updates the Kubernetes deployment YAML in the Git repository with the new image tag.

B.Continuous Deployment (ArgoCD) :

1.Model: Pull-based deployment.
2.Sync: ArgoCD, running inside the cluster, detects the image tag update in the Git repository.
3.Action: It automatically syncs the "Live State" of the cluster with the "Desired State" in Git, performing a rolling update of the microservices.






