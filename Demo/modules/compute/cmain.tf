variable "project_name" {}
variable "public_subnet_id" {}
variable "private_subnet_id" {}
variable "bastion_sg_id" {}
variable "k3s_node_sg_id" {}
variable "jenkins_sg_id" {}
variable "key_name" {}
variable "jenkins_script" {} # Receives content from Root
variable "master_script" {}  # Receives content from Root
variable "worker_script" {}  # Receives content from Root

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}


# --- 1. BASTION (Public | t3.micro | Jumpbox Only) ---
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = var.public_subnet_id
  key_name      = var.key_name
  # Only Bastion SG
  vpc_security_group_ids = [var.bastion_sg_id]
  
  tags = { Name = "${var.project_name}-bastion" }
}

# --- 2. JENKINS SERVER (Private | m7i-flex.large) ---
resource "aws_instance" "jenkins" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "m7i-flex.large"
  subnet_id     = var.private_subnet_id
  key_name      = var.key_name
  # Uses K8s SG because it needs to talk to the cluster (deploy apps)
  vpc_security_group_ids = [var.jenkins_sg_id]
  
  user_data = var.jenkins_script

  tags = { Name = "${var.project_name}-jenkins" }
}

# --- 3. K3s CONTROL PLANE (Private | m7i-flex.large) ---
resource "aws_instance" "k3s_master" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "m7i-flex.large"
  subnet_id     = var.private_subnet_id
  key_name      = var.key_name
  vpc_security_group_ids = [var.k3s_node_sg_id]

  user_data = var.master_script

  tags = { Name = "${var.project_name}-k3s-master" }
}



# --- 4. K3s WORKER NODE (Private | m7i-flex.large | 30GB) ---
resource "aws_instance" "k3s_worker" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "m7i-flex.large"
  subnet_id     = var.private_subnet_id
  key_name      = var.key_name
  vpc_security_group_ids = [var.k3s_node_sg_id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    delete_on_termination = true
  }

  user_data = var.worker_script

  tags = { Name = "${var.project_name}-k3s-worker-app" }
}



# --- 5. MONITORING NODE (Private | m7i-flex.large | 30GB) ---
# This is technically a "Worker" that joins the cluster, but intended for PLG.
resource "aws_instance" "monitoring" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "m7i-flex.large"
  subnet_id     = var.private_subnet_id
  key_name      = var.key_name
  vpc_security_group_ids = [var.k3s_node_sg_id]
  
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    delete_on_termination = true
  }

  user_data = var.worker_script

  tags = { Name = "${var.project_name}-k3s-monitoring" }
}


