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
  default     = "admin"
  type        = string
}

variable "db_password" {
  description = "The password for the database"
  default     = "admin1234!"
  type        = string
}

# VPC Configuration
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Subnet for the EC2 instance
resource "aws_subnet" "ec2_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

# Create two subnets for RDS in different AZs
resource "aws_subnet" "rds_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "rds_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
}

# Internet Gateway for the VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Route table and association for internet access
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

# Security group for the web server (EC2)
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

# EC2 instance as a web server
resource "aws_instance" "web_server" {
  ami           = var.ami
  instance_type = var.instance_type
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
    Name = "${var.name_tag}-webserver"
  }
}

# Security group for RDS
resource "aws_security_group" "db_sg" {
  name        = "my-db-security-group"
  description = "Database security group"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"] # Restrict to the EC2 subnet
  }
}

# DB Subnet Group with both subnets
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "Ali-db-subnet-group"
  subnet_ids = [aws_subnet.rds_subnet_1.id, aws_subnet.rds_subnet_2.id]
}

# RDS instance - PostgreSQL
resource "aws_db_instance" "postgres_db" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "12.8"
  instance_class       = "db.t2.micro"
  db_name              = "mydatabase"
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.postgres12"
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot  = true
}
