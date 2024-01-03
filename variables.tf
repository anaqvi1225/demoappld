variable "ami" {
  type        = string
  description = "Ubuntu AMI ID in N. Virginia Region"
  default     = "ami-0c7217cdde317cfec"
}

variable "instance_type" {
  type        = string
  description = "Instance type"
  default     = "t2.micro"
}

variable "name_tag" {
  type        = string
  description = "Name of the EC2 instance"
  default     = "My EC2 Instance"
}

variable "db_username" {
  description = "The username for the database"
  type        = string
}

variable "db_password" {
  description = "The password for the database"
  type        = string
}

provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MyVPC"
  }
}

# Subnets
resource "aws_subnet" "ec2_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "ec2-subnet"
  }
}

resource "aws_subnet" "rds_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "rds-subnet-1"
  }
}

resource "aws_subnet" "rds_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "rds-subnet-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Route Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.ec2_subnet.id
  route_table_id = aws_route_table.rt.id
}

# Security Groups
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  description = "Security group for HTTP access to the web server"
  vpc_id      = aws_vpc.my_vpc.id

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

resource "aws_security_group" "db_sg" {
  name        = "my-db-security-group"
  description = "Database security group"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }
}

# EC2 instance
resource "aws_instance" "web_server" {
  ami           = "ami-0c7217cdde317cfec" # Change as necessary
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.ec2_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install -y apache2
                sudo systemctl start apache2
                sudo systemctl enable apache2
                echo 'Hello Ali' | sudo tee /var/www/html/index.html
                EOF

  tags = {
    Name = "My EC2 Instance-webserver"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.rds_subnet_1.id, aws_subnet.rds_subnet_2.id]

  tags = {
    Name = "My DB Subnet Group"
  }
}

# RDS Instance
resource "aws_db_instance" "postgres_db" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "12.4" # Change as necessary
  instance_class       = "db.t2.micro"
  db_name              = "mydatabase"
  username             = "dbuser"
  password             = "mysecurepassword"
  parameter_group_name = "default.postgres12"
  skip_final_snapshot  = true

  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
}
