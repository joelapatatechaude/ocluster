# Provider configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "tailscale-key"
}

# SSH Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file("~/.ssh/id_rsa.pub")

  tags = {
    Name = "tailscale-ssh-key"
  }
}

variable "my_ip" {
  description = "Your IP address(es) for SSH access (CIDR notation, e.g., ['1.2.3.4/32', '5.6.7.8/32'])"
  type        = list(string)
}

variable "ami_id" {
  description = "Fedora AMI ID (optional - only used if ami_name is not set)"
  type        = string
  default     = ""
}

variable "openshift_cluster_name" {
  description = "OpenShift cluster name"
  type        = string
  default     = "my-cluster"
}

variable "corporate_subnet_cidr" {
  description = "Corporate subnet CIDR to route via Tailscale (e.g., 10.76.18.0/23)"
  type        = string
}

variable "tailscale_router_private_ip" {
  description = "Static private IP for Tailscale router"
  type        = string
  default     = "10.0.1.10"
}

# Data source for specific Fedora AMI by name
data "aws_ami" "fedora" {
  most_recent = true
  owners      = ["125523088429"] # Official Fedora Project account

  filter {
    name   = "name"
    values = ["*Fedora-Cloud-Base-AmazonEC2.x86_64-43-1*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for RHEL CoreOS AMI
data "aws_ami" "rhcos" {
  most_recent = true
  owners      = ["531415883065"] # RHCOS owner ID

  filter {
    name   = "name"
    values = ["rhcos-418*x86_64*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "tailscale-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "tailscale-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "tailscale-public-subnet"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "tailscale-private-subnet"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "tailscale-public-rt"
  }
}

# Route Table Association - Public
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Route to corporate subnet via Tailscale router
resource "aws_route" "corporate_subnet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = var.corporate_subnet_cidr
  network_interface_id   = aws_instance.tailscale_router.primary_network_interface_id

  depends_on = [aws_instance.tailscale_router]
}

# Route Table - Private
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "tailscale-private-rt"
  }
}

# Route Table Association - Private
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Route to corporate subnet via Tailscale router (for private subnet)
resource "aws_route" "corporate_subnet_private" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = var.corporate_subnet_cidr
  network_interface_id   = aws_instance.tailscale_router.primary_network_interface_id

  depends_on = [aws_instance.tailscale_router]
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}


###
# Security Group for Tailscale Router (Instance 1)
resource "aws_security_group" "tailscale_router" {
  name        = "tailscale-router-sg"
  description = "Security group for Tailscale router instance"
  vpc_id      = aws_vpc.main.id

  # SSH from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.my_ip
    description = "SSH from allowed IPs"
  }

  # Tailscale UDP
  ingress {
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Tailscale"
  }

  # Allow all traffic from within VPC (for subnet routing)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "All traffic from VPC"
  }

  # NEW: Allow all traffic from corporate subnet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.corporate_subnet_cidr]
    description = "All traffic from corporate subnet"
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "tailscale-router-sg"
  }
}

# Security Group for Private Instance (Instance 2)
resource "aws_security_group" "private_instance" {
  name        = "private-instance-sg"
  description = "Security group for private instance accessible via Tailscale"
  vpc_id      = aws_vpc.main.id

  # SSH from your IP addresses
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.my_ip
    description = "SSH from allowed IPs"
  }

  # SSH from within VPC (via Tailscale router)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "SSH from VPC"
  }

  # Allow all traffic from within VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "All traffic from VPC"
  }

  # NEW: Allow all traffic from corporate subnet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.corporate_subnet_cidr]
    description = "All traffic from corporate subnet"
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "private-instance-sg"
  }
}
###


# Security Group for OpenShift Worker
resource "aws_security_group" "openshift_worker" {
  name        = "openshift-worker-sg"
  description = "Security group for OpenShift worker node"
  vpc_id      = aws_vpc.main.id

  # Allow all traffic from within VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "All traffic from VPC"
  }

  # Allow traffic from corporate subnet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.corporate_subnet_cidr]
    description = "All traffic from corporate subnet"
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "openshift-worker-sg"
  }
}

# EC2 Instance 1 - Tailscale Router
resource "aws_instance" "tailscale_router" {
  ami                    = data.aws_ami.fedora.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.tailscale_router.id]
  private_ip             = var.tailscale_router_private_ip
  source_dest_check      = false # Required for subnet routing

  user_data = <<-EOF
              #!/bin/bash
              
              # Set hostname
              sudo hostnamectl set-hostname aws-subnet-router
              
              # Enable IP forwarding for subnet routing
              echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
              echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
              sudo sysctl -p
              
              # Update system
              sudo dnf update -y
              
              # Install Tailscale
              sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo
              sudo dnf install -y tailscale
              
              # Enable Tailscale service (but don't start it yet)
              sudo systemctl enable tailscaled
              sudo systemctl start tailscaled
              EOF

  tags = {
    Name = "tailscale-router"
    Role = "router"
  }
}

# EC2 Instance 2 - Private Instance
resource "aws_instance" "private_instance" {
  ami                    = data.aws_ami.fedora.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.private_instance.id]
  
  # Enable public IP for outbound internet access
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              # Update system
              sudo dnf update -y
              EOF

  tags = {
    Name = "private-instance"
    Role = "private"
  }
}

# Outputs
output "tailscale_router_public_ip" {
  description = "Public IP of Tailscale router instance"
  value       = aws_instance.tailscale_router.public_ip
}

output "tailscale_router_private_ip" {
  description = "Private IP of Tailscale router instance"
  value       = aws_instance.tailscale_router.private_ip
}

output "private_instance_public_ip" {
  description = "Public IP of private instance (for outbound internet access only)"
  value       = aws_instance.private_instance.public_ip
}

output "private_instance_private_ip" {
  description = "Private IP of private instance"
  value       = aws_instance.private_instance.private_ip
}

output "vpc_cidr" {
  description = "VPC CIDR block to advertise as subnet route"
  value       = aws_vpc.main.cidr_block
}

output "fedora_ami_id" {
  description = "Fedora AMI ID used"
  value       = data.aws_ami.fedora.id
}

output "fedora_ami_name" {
  description = "Fedora AMI name used"
  value       = data.aws_ami.fedora.name
}

# output "openshift_worker_public_ip" {
#   description = "Public IP of OpenShift worker node"
#   value       = aws_instance.openshift_worker.public_ip
# }

# output "openshift_worker_private_ip" {
#   description = "Private IP of OpenShift worker node"
#   value       = aws_instance.openshift_worker.private_ip
# }

output "rhcos_ami_id" {
  description = "RHEL CoreOS AMI ID used"
  value       = data.aws_ami.rhcos.id
}

output "rhcos_ami_name" {
  description = "RHEL CoreOS AMI name used"
  value       = data.aws_ami.rhcos.name
}