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

resource "aws_security_group" "allow_http4" {
  name        = "allow_http4"
  description = "Allow HTTP inbound traffic"
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "app" {
  name          = "app-launch-configuration"
  image_id      = "ami-012c2e8e24e2ae21d"  # Update with your Amazon Linux 2023 AMI ID
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.allow_http4.id]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              echo "Provisioning complete. Ansible will now configure the instance."
              EOF
}

resource "aws_autoscaling_group" "app" {
  launch_configuration = aws_launch_configuration.app.id
  min_size             = 2
  max_size             = 4
  desired_capacity     = 2
  vpc_zone_identifier  = data.aws_vpc.default.subnets

  tag {
    key                 = "Name"
    value               = "REST API Service"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "main" {
  name               = "jaime-load-balancer"
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

  instances                   = aws_autoscaling_group.app.instances
  security_groups             = [aws_security_group.allow_http4.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "jaime-load-balancer"
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${self.private_ip}, playbook.yml"
  }

  output "instance_private_ips" {
    value = aws_instance.app[*].private_ip
  }
}
