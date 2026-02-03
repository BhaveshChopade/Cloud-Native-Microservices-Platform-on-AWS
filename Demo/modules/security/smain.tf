variable "vpc_id" {}
variable "project_name" {}
variable "ssh_allowed_cidrs" {
  type = list(string)
}


################################
# Bastion Security Group
################################
resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-bastion-sg"
  description = "Bastion SSH access"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

resource "aws_security_group_rule" "bastion_ssh_in" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_allowed_cidrs
  security_group_id = aws_security_group.bastion_sg.id
}

resource "aws_security_group_rule" "bastion_all_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion_sg.id
}


################################
# Jenkins Security Group
################################

resource "aws_security_group" "jenkins_sg" {
  name        = "${var.project_name}-jenkins-sg"
  description = "Jenkins (private access via bastion / tunnel only)"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-jenkins-sg"
  }
}

resource "aws_security_group_rule" "jenkins_ssh_from_bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
  security_group_id        = aws_security_group.jenkins_sg.id
}

resource "aws_security_group_rule" "jenkins_ui_internal" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
  security_group_id        = aws_security_group.jenkins_sg.id
}

resource "aws_security_group_rule" "jenkins_self_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.jenkins_sg.id
  security_group_id        = aws_security_group.jenkins_sg.id
  description              = "SELF reference required for SSH tunnel Jetty async"
}

resource "aws_security_group_rule" "jenkins_all_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins_sg.id
}



################################
# K3s Nodes Security Group
################################
resource "aws_security_group" "k3s_nodes_sg" {
  name        = "${var.project_name}-k3s-nodes-sg"
  description = "K3s master and workers"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-k3s-nodes-sg"
  }
}

# SSH from Bastion ONLY
resource "aws_security_group_rule" "k3s_ssh_from_bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
  security_group_id        = aws_security_group.k3s_nodes_sg.id
}

# K3s API — workers → master (CRITICAL)
resource "aws_security_group_rule" "k3s_api_6443" {
  type                     = "ingress"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.k3s_nodes_sg.id
  security_group_id        = aws_security_group.k3s_nodes_sg.id
}

# HTTP for NLB / App
resource "aws_security_group_rule" "k3s_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s_nodes_sg.id
}

# Internal cluster traffic (Flannel, kubelet, metrics, etc.)
  resource "aws_security_group_rule" "k3s_all_internal" {
    type                     = "ingress"
    from_port                = 0
    to_port                  = 0
    protocol                 = "-1"
    source_security_group_id = aws_security_group.k3s_nodes_sg.id
    security_group_id        = aws_security_group.k3s_nodes_sg.id
  }

# Egress (required for pull images, GitHub, etc.)
resource "aws_security_group_rule" "k3s_all_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s_nodes_sg.id
}