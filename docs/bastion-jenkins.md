# Bastion -> Private Jenkins bootstrap

Architecture:

Mac --SSH/PEM--> Bastion EC2 (Public Subnet A) --SSH--> Jenkins EC2 (Private Subnet A)
                                                     |
                                                     +--> NAT Gateway --> Internet/ECR/GitLab outbound

## 1. Prepare variables

Copy terraform.tfvars.example to terraform.tfvars and set:

- ec2_key_name: existing EC2 Key Pair name in ap-northeast-2
- admin_cidr: your current public IPv4 address with /32

Keep the matching PEM file only on your Mac. Do not copy the PEM to the Bastion host.

## 2. Terraform

terraform init
terraform fmt -recursive
terraform validate
terraform plan -target=aws_instance.bastion -target=aws_instance.jenkins
terraform apply -target=aws_instance.bastion -target=aws_instance.jenkins

## 3. SSH with ProxyJump (recommended)

terraform output bastion_public_ip
terraform output jenkins_private_ip

ssh -i /path/to/key.pem -J ec2-user@BASTION_PUBLIC_IP ec2-user@JENKINS_PRIVATE_IP

This keeps the PEM file on the Mac and uses the Bastion only as an SSH jump host.

## 4. Jenkins UI via SSH tunnel

ssh -i /path/to/key.pem \
  -J ec2-user@BASTION_PUBLIC_IP \
  -L 8080:localhost:8080 \
  ec2-user@JENKINS_PRIVATE_IP

Then browse to http://localhost:8080 on the Mac.

Initial password on Jenkins:

sudo cat /var/lib/jenkins/secrets/initialAdminPassword

## Important

- NAT Gateway is outbound-only. It does not make GitLab webhook traffic reach private Jenkins.
- Bastion is for administrator SSH access, not for GitLab webhook delivery.
- For GitLab.com -> private Jenkins webhook, use a controlled inbound path such as a public ALB/reverse proxy, or use polling until that path is built.
