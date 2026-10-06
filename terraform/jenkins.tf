data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_security_group" "jenkins_sg" {
  name        = "ai-travel-jenkins-sg"
  description = "Jenkins in private subnet - SSH only from Bastion and managed through SSM"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ai-travel-jenkins-sg"
  }
}

resource "aws_iam_role" "jenkins_ec2_role" {
  name = "ai-travel-jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role       = aws_iam_role.jenkins_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "jenkins_ecr" {
  name = "ai-travel-jenkins-ecr-push"
  role = aws_iam_role.jenkins_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = aws_ecr_repository.backend.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "ai-travel-jenkins-instance-profile"
  role = aws_iam_role.jenkins_ec2_role.name
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.private_a.id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  key_name                    = var.ec2_key_name

  user_data = <<-USERDATA
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y java-17-amazon-corretto-headless git docker wget awscli2

    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    dnf install -y jenkins

    systemctl enable --now docker
    usermod -aG docker jenkins

    systemctl enable jenkins
    systemctl start jenkins
    systemctl restart jenkins
  USERDATA

  depends_on = [
    aws_route_table_association.private_a,
    aws_iam_role_policy_attachment.jenkins_ssm,
    aws_iam_role_policy.jenkins_ecr
  ]

  tags = {
    Name = "ai-travel-jenkins"
  }
}

output "jenkins_instance_id" {
  description = "SSM 접속에 사용할 Jenkins EC2 Instance ID"
  value       = aws_instance.jenkins.id
}

output "jenkins_private_ip" {
  description = "Jenkins EC2 Private IP"
  value       = aws_instance.jenkins.private_ip
}
