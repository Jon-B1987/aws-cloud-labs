
# Terraform settings block
terraform {
  # Required providers Terraform must download
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
}

# configure AWS provider
provider "aws" {
  # region where infrastructure will be built
  region = "us-east-1"

}

# generate unique id for s3 bucket
resource "random_id" "bucket_id" {
  byte_length = 4

}

# create s3 bucket
resource "aws_s3_bucket" "lab4_bucket" {
  # using a random string for bucket id
  bucket = "lab4-terraform-${random_id.bucket_id.hex}"

}

# create security group for load balencer
resource "aws_security_group" "alb_sg" {
  name   = "lab4-alb-sg"
  vpc_id = aws_vpc.lab4_vpc.id

  # allow internet traffic to the aplication load balencer
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow load balencer to send the traffic out
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create security group for EC2 instances
resource "aws_security_group" "web_sg" {
  name   = "lab4-ec2-sg"
  vpc_id = aws_vpc.lab4_vpc.id

  # allow HTTP traffic ONLY from load balancer
  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  #allow ssh access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create vpc
resource "aws_vpc" "lab4_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "lab4-vpc"
  }

}

# create subnet a
resource "aws_subnet" "lab4_subnet_a" {
  vpc_id                  = aws_vpc.lab4_vpc.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "lab4-subnet-a"
  }

}

# create subnet b
resource "aws_subnet" "lab4_subnet_b" {
  vpc_id                  = aws_vpc.lab4_vpc.id
  cidr_block              = "10.0.20.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "lab4-subnet-b"
  }

}

# create internet gateway
resource "aws_internet_gateway" "lab4_igw" {
  vpc_id = aws_vpc.lab4_vpc.id
}

# create route table
resource "aws_route_table" "lab4_rt" {
  vpc_id = aws_vpc.lab4_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab4_igw.id
  }

}

# associate route table with subnet a
resource "aws_route_table_association" "lab4_assoc_a" {
  subnet_id      = aws_subnet.lab4_subnet_a.id
  route_table_id = aws_route_table.lab4_rt.id

}

# associate route table with subnet b
resource "aws_route_table_association" "lab4_assoc_b" {
  subnet_id      = aws_subnet.lab4_subnet_b.id
  route_table_id = aws_route_table.lab4_rt.id

}

# get latest amazon linux ami
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"
    # Filter to find Amazon Linux 2, HVM virtualization, EBS-backed, x86_64 architecture
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

}

# create 3 ec2 instances
resource "aws_instance" "web" {
  count         = 3
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.lab4_subnet_a.id

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # script will run when server starts
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install httpd -y
              systemctl start httpd
              systemctl enable httpd
              echo "Hello from Terraform EC2 instance" > /var/www/html/index.html
              EOF

  # unique server name
  tags = {
    Name = "Terraform-Web-${count.index}"
  }
}

# creat load balencer
resource "aws_lb" "web_lb" {
  name               = "lab4-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [aws_subnet.lab4_subnet_a.id,
  aws_subnet.lab4_subnet_b.id]

}

# target group(tells the load balencer where to send traffic)
resource "aws_lb_target_group" "web_tg" {
  name     = "lab4-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.lab4_vpc.id


}

# attach ec2 instances to target group
resource "aws_lb_target_group_attachment" "web_attach" {
  count            = 3
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80

}

# listener(this tells the load balancer how to route traffic)
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }

}

# Output the public DNS name of the Application Load Balancer
# This lets us access the web app in a browser after infrastructure is created
output "load_balencer_dns" {
  description = "Public DNS of the load balencer"
  value       = aws_lb.web_lb.dns_name

}
