provider "aws" {
  region = "ap-southeast-1"  # Ensure this is the correct region for your resources
}

data "aws_vpc" "default" {
  default = true
}

variable "public_ssh_key" {
  description = "Public SSH key for EC2 key pair"
  type        = string
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.public_ssh_key
}

resource "aws_security_group" "allow_http5" {
  name        = "allow_http5"
  description = "Allow HTTP inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami           = "ami-012c2e8e24e2ae21d"  # Verify the AMI ID for your region
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.allow_http5.id]

  user_data = <<-EOF
              #!/bin/bash
              set -e

              echo "Updating system packages..."
              yum update -y

              echo "Installing Docker..."
              yum install -y docker

              echo "Starting Docker service..."
              systemctl start docker
              systemctl enable docker

              echo "Adding ec2-user to Docker group..."
              usermod -aG docker ec2-user

              echo "Running Docker container..."
              docker run -d -p 3000:3000 --name rest-api-service jaimejr551/devops-test-rest-api-service:latest

              echo "Checking Docker status..."
              systemctl status docker

              echo "Checking running containers..."
              docker ps

              echo "Checking Docker container logs..."
              docker logs rest-api-service
              EOF

  tags = {
    Name = "REST API Service"
  }
} 
