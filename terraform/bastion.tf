# =======================================================
# Bastion EC2 (Public Subnet A)
# Mac -> Bastion(Public IP, PEM) -> Jenkins(Private IP)
# =======================================================

variable "ec2_key_name" {
  description = "Existing EC2 Key Pair name in ap-northeast-2. Keep the matching .pem file on your Mac."
  type        = string
}

variable "admin_cidr" {
  description = "Your current public IPv4 address in CIDR form, e.g. 203.0.113.10/32"
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr must be a valid CIDR and must not be 0.0.0.0/0. Use your public IP/32."
  }
}

resource "aws_security_group" "bastion_sg" {
  name        = "ai-travel-bastion-sg"
  description = "SSH to Bastion only from administrator public IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from administrator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ai-travel-bastion-sg"
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  key_name                    = var.ec2_key_name

  depends_on = [aws_route_table_association.public_a]

  lifecycle {
    ignore_changes = [
      ami
    ]
  }

  tags = {
    Name = "ai-travel-bastion"
  }
}

output "bastion_public_ip" {
  description = "Public IP used by your Mac to SSH to the Bastion host"
  value       = aws_instance.bastion.public_ip
}

# Bastion 고정 Public IP
resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name = "ai-travel-bastion-eip"
  }
}

resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}

output "bastion_eip" {
  description = "Fixed public IP for Bastion"
  value       = aws_eip.bastion.public_ip
}