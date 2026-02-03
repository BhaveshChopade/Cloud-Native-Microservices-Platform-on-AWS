variable "vpc_cidr" {}
variable "project_name" {}

# 1. VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  assign_generated_ipv6_cidr_block = false #to stop the use of ipv6

  tags = { Name = "${var.project_name}-vpc" }
}

# 2. Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-igw" }
}

# 3. Public Subnet (Single AZ)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1) # 10.0.1.0/24
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a" # Hardcoded for Single AZ Simplicity
  tags = { Name = "${var.project_name}-public" }
}

# 4. Private Subnet (Single AZ)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2) # 10.0.2.0/24
  availability_zone = "us-east-1a" # Same AZ for low latency
  tags = { Name = "${var.project_name}-private" }
}

# 5. Route Table (Public)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }


}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 6. NAT Gateway (For Private Nodes to reach Internet)
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = { Name = "${var.project_name}-nat" }
}

# 7. Route Table (Private)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}