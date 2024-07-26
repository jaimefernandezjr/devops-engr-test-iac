provider "aws" {
  region = "ap-southeast-1" 
}

terraform {
  backend "s3" {
    bucket = "devops-test-tfstate-bucket"
    key    = "devops-test.tfstate"
    region = "ap-southeast-1"
    dynamodb_table = "terraform-locks"
  }
}

data "aws_vpc" "default" {
  default = true
}

variable "public_ssh_key" {
  description = "Public SSH key for EC2 key pair"
  type        = string
}

resource "aws_key_pair" "deployer2" {
  key_name   = "deployer2-key"
  public_key = var.public_ssh_key
}

resource "aws_security_group" "sg_restrict_traffic1" {
  name        = "sg_restrict_traffic1"
  description = "Restrict inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_instance" "ec2" {
  count         = 2
  ami           = "ami-012c2e8e24e2ae21d"  
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer2.key_name

  vpc_security_group_ids = [aws_security_group.sg_restrict_traffic1.id]

  user_data = <<-EOF
              #!/bin/bash
              set -e

              echo "Updating system packages..."
              sudo yum update -y

              echo "Installing Docker..."
              sudo yum install -y docker

              echo "Starting Docker service..."
              sudo systemctl start docker
              sudo systemctl enable docker

              echo "Adding ec2-user to Docker group..."
              sudo usermod -aG docker ec2-user

              echo "Running Docker container..."
              sudo docker run -d -p 3000:3000 --name rest-api-service jaimejr551/devops-test-rest-api-service:latest

              echo "Checking Docker status..."
              sudo systemctl status docker

              echo "Checking running containers..."
              sudo docker ps

              echo "Checking Docker container logs..."
              sudo docker logs rest-api-service
              EOF

  tags = {
    Name = "REST API Service ${count.index + 1}"
  }
}

resource "aws_elb" "main" {
  name               = "jaimejr-load-balancer"
  availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

  listener {
    instance_port     = 3000
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:3000/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances                   = [aws_instance.ec2[0].id, aws_instance.ec2[1].id]
  security_groups             = [aws_security_group.sg_restrict_traffic1.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "jaimejr-load-balancer"
  }
}
