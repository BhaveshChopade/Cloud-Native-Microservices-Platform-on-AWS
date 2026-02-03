variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project Name"
  type        = string
  default     = "Demo"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}


variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH into bastion and private nodes"
  type        = list(string)
  default     = ["0.0.0.0/0"]

}


variable "key_name" {
  description = "Name of the existing EC2 Key Pair"
  type        = string
  default     = "robot-shop-key" # Matches your .pem file name (without extension)
}

