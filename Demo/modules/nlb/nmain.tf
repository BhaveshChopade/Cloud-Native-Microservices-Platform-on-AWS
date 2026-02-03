variable "project_name" {}
variable "vpc_id" {}
variable "public_subnet_id" {}
variable "worker_ids" { type = list(string) }

resource "aws_lb" "k3s_nlb" {
  name               = "${var.project_name}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [var.public_subnet_id] # Single AZ list
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "traefik_80" {
  name     = "${var.project_name}-traefik-80"
  port     = 80
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.k3s_nlb.arn
  port              = "80"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.traefik_80.arn
  }
}

resource "aws_lb_target_group_attachment" "nodes" {
  count            = length(var.worker_ids)
  target_group_arn = aws_lb_target_group.traefik_80.arn
  target_id        = var.worker_ids[count.index]
  port             = 80
}