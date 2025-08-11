provider "aws" {
  region = "us-east-1"
}
#provider "azure" {
#  features {}
#}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "access-key"
  secret_key = "secret-key"
}


# resource "<provider>_<resource_type>" "name"{
#     #config options
#     key = "value"
#     key2 = "another value"
# }

# developing ec2 in terraform
resource "aws_instance" "my_first_server" {
  ami           = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type = "t3.micro"

    tags = {
        Name = "MyFirstServer"
    }
}
# declarative manner : # we are declaring what we want to have, not how to do it. So no matter how many times we run this code, it will always create the same resource once. 
# our actual state in AWS will match whats being defined in the code
# creates a text file called terraform.tfstate in the current directory, which contains the current state of the infrastructure managed by Terraform. format: JSON

#creating VPC and a subnet within that VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0/16"
    tags = {
        Name = "MyVPC"
    }
}

#subnet within the VPC
resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id #refrencing the VPC created above, as every resource has an ID that can be referrenced
  cidr_block        = "10.0.0/24"
    tags = {
        Name = "MySubnet"
    }
}
# the order in which you write the resources does not matter, as Terraform will figure out the dependencies and create them in the correct order

#terraform init command, plan command, apply command, destroy command, fmt
#terraform init - to initialize the working directory containing Terraform configuration files 
# that is basically downloads the provider plugins required for the configuration


#terraform plan - to create an execution plan. It is a quick sanity check to see all runs an dyou are not gonna break anything
# color codes in the plan output:
# + is create a resource
# - is destroy a resource

#terraform apply - to apply the changes required to reach the desired state of the configuration
# creates our server 


#terraform destroy - to destroy the Terraform-managed infrastructure
# to delete just comment the code, and it will delete the resource on next apply

# reference resources

#terraform fmt - to format the configuration files in the directory

# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       }
#   }
# }


# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# Create a Custom Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "production-route-table"
  }
}

# Create a subnet

resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "production-subnet-1"
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "subnet-1-association" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Create a security group to allow port 22, 80, and 443
resource "aws_security_group" "allow-web" {
  name        = "allow-web-traffic"
  description = "Allow SSH, HTTP, and HTTPS traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-web-traffic"
  }
}

# Create a Network Interface
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.allow-web.id]

  tags = {
    Name = "web-server-nic"
  }
}

# Assign an elastic IP to the network interface
resource "aws_eip" "web-server-eip" {
  domain   = "vpc"
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.gw ]
}

# Create an Ubuntu EC2 instance

resource "aws_instance" "web-server-instance" {
  ami           = "ami-ami-020cba7c55df1f615"
  instance_type = "t3.micro"
  key_name      = "D:/DevOps/Keys/tf-access-key.pem"
  availability_zone = "us-east-1a"

  network_interface {
    network_interface_id = aws_network_interface.web-server-nic.id
    device_index         = 0
  }

  tags = {
    Name = "web-server"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    sudo bash -c 'echo your very first web server > /var/www/html/index.html'
    EOF
}