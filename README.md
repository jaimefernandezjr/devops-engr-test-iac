# Rest API Service Continuous Deployment on AWS with Terraform and GitHub Actions

## Overview
This is the continuous deployment part of the CI/CD for Deploying REST API Service on AWS with GitHub Actions and Terraform that is located in the https://github.com/jaimefernandezjr/devops-engr-test repository. The GitHub Actions workflow provisions AWS resources using Terraform to allow the application be deployed in the AWS cloud.

## The Terraform file
This Terraform configuration:
- Configures AWS as the provider and sets up the backend for state management using S3 and DynamoDB.
- Retrieves the default VPC.
- Defines a variable for the public SSH key used for EC2 access.
- Creates an EC2 key pair for SSH access.
- Creates a security group with rules for inbound traffic on ports 3000 (application), 80 (HTTP), and 22 (SSH), and allows all outbound traffic.
- Creates two EC2 instances configured with Docker, and deploys a Docker container running a REST API service.
- Creates an Elastic Load Balancer to distribute traffic across the EC2 instances, with health checks and load balancing features enabled.

## The GitHub Actions CD workflow
This workflow does the following:
- Sets up AWS credentials and environment for Terraform.
- Creates an S3 bucket and DynamoDB table for Terraform state and locks.
- Deploys infrastructure using Terraform, including initializing and applying the configuration.

## Known Issue
### Terraform Destroy
Currently, the terraform destroy command does not successfully remove all resources due to a problem. The workflow takes too long to execute the Terraform Apply step, where it is taking way too long to obtain public ssh key.  To clean up, I manually delete the resources from the AWS Management Console.

## Future Improvements
- Implement auto-scaling for the EC2 instances.
- Use Ansible for configuration management.
- Add automated tests for the infrastructure.
