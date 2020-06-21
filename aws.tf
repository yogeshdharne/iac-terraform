provider aws {
  access_key = ""
  secret_key = ""
  region     = "ap-south-1"
}

#Creating VPC
resource "aws_vpc" "custom_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    name = "custom_vpc"
  }
}

#Creating Internet Gateway
resource "aws_internet_gateway" "internetgw" {
  vpc_id = "${aws_vpc.custom_vpc.id}"
  tags = {
    name = "custom_igw"
  }

}

#Creating 2 Private and 2 Public Subnet
resource "aws_subnet" "private1" {
    vpc_id = "${aws_vpc.custom_vpc.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone_id = "aps1-az1"
    tags = {
   name = "private_subnet1"
  }
}

resource "aws_subnet" "private2" {
    vpc_id = "${aws_vpc.custom_vpc.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone_id = "aps1-az2"
    tags = {
   name = "private_subnet2"
  }
}

resource "aws_subnet" "public1" {
    vpc_id = "${aws_vpc.custom_vpc.id}"
  cidr_block = "10.0.3.0/24"
  availability_zone_id = "aps1-az1"
    tags = {
   name = "public_subnet1"
  }
}

resource "aws_subnet" "public2" {
    vpc_id = "${aws_vpc.custom_vpc.id}"
  cidr_block = "10.0.4.0/24"
  availability_zone_id = "aps1-az2"
    tags = {
   name = "public_subnet2"
  }
}



#Create Rout Table For Public Subnet
resource "aws_route_table" "route" {
  vpc_id = "${aws_vpc.custom_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internetgw.id}"

  }
  tags = {
    name = "public_route"
  }
}

#Adding Public Subnet to Route Table
resource "aws_route_table_association" "public1" {
  subnet_id      = "${aws_subnet.public1.id}"
  route_table_id = "${aws_route_table.route.id}"
}

resource "aws_route_table_association" "public2" {
  subnet_id      = "${aws_subnet.public2.id}"
  route_table_id = "${aws_route_table.route.id}"
}

resource "aws_eip" "natgw_eip" {
  vpc = true
}

#Creting Route Table For Private Subnet
resource "aws_nat_gateway" "natgw" {
  allocation_id = "${aws_eip.natgw_eip.id}"
  subnet_id     = "${aws_subnet.public1.id}"
  tags = {
    name = "natgateway"
  }
}

#Add Route For Private Subnet to Nat Gateway
resource "aws_route_table" "route_private" {
  vpc_id = "${aws_vpc.custom_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.natgw.id}"

  }
  tags = {
    name = "private_route"
  }
}

#Adding Private Subnet to Route Table
resource "aws_route_table_association" "private1" {
  subnet_id      = "${aws_subnet.private1.id}"
  route_table_id = "${aws_route_table.route_private.id}"
}

resource "aws_route_table_association" "private2" {
  subnet_id      = "${aws_subnet.private2.id}"
  route_table_id = "${aws_route_table.route_private.id}"
}

#Create IAM Role For Web EC2 With Permission Of RDS
resource "aws_iam_role" "web_role" {
  name = "web_role"

  assume_role_policy = <<EOF
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [ "rds.amazonaws.com" ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "web_profile" {
  name = "web_profile"
  role = "${aws_iam_role.web_role.name}"
}


resource "aws_iam_role_policy" "web_policy" {
  name = "web_policy"
  role = "${aws_iam_role.web_role.id}"

  policy = <<EOF
{
  "Statement": [
    {
      "Action": [
        "rds:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}


#Creating Security Group For Web EC2
resource "aws_security_group" "web" {
  name        = "web"
  vpc_id      = "${aws_vpc.custom_vpc.id}"
  description = "Created by terraform"

  ingress {
    from_port   = 22
    to_port     = 22
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
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#SSH Public Key For Accessing Web EC2 Server
resource "aws_key_pair" "auth" {
  key_name   = "mytestpubkey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtokFRnE47PsNY4UA/5kGgW1e3UBMLQsMhf+g2mI2IYEX7qKxaMCMim3uJgs8pIvD0zy6rxUUCOBfZOQtkzIMzVPv6SNPk0H7BvnXIwmlBVogIa5gWdpQXW10MD6TPeuAaghPPdDWfYkOosKIT2uf9hk7NVAwrGoBamSx10+Ln+ShvkEs5UY1Y6FIqvjGbeOzers3ANMYk40cEJdZQ4NmrXuR3A1CUwfkXAfu3keXEzVCzT5gvwnS94CdTx2+K6g3rFk0MyAbrAfaRNreoP6djfpld/nI+NWVoe5gDH1efz/7JVOIHUHo7pesfEIht/MmpoIJVr2X9DRzOJPoLDxh7 mosip@mosip-devops"
}


#Creating Web EC2 Server With IAM Role and Installing Nginx and PHP-FPM
resource "aws_instance" "web_server" {
  ami                  = "ami-0b44050b2d893d5f7"
  instance_type        = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.web_profile.name}"
  subnet_id            = "${aws_subnet.public1.id}"
  private_ip = "10.0.3.40"
  #security_groups      = ["${aws_security_group.default.name}"]
  vpc_security_group_ids = ["${aws_security_group.web.id}"]
  key_name             = "${aws_key_pair.auth.id}"

  #  provisioner "remote-exec" {
  #    inline = [
  #	  "sudo yum -y install epel-release",
  #      "sudo yum -y update",
  #      "sudo yum -y install nginx",
  #	    "sudo yum -y install php php-mysql php-fpm",
  #      "sudo systemctl start nginx",
  #	    "sudo systemctl start php-fpm"
  #    ]
  #  }
  user_data = <<-EOF
                #!/bin/bash
                sudo apt-get -y update
                sudo apt-get -y install \
                  apt-transport-https \
                  ca-certificates \
                  curl \
                  gnupg-agent \
                  software-properties-common
                add-apt-repository \
                  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
                   $(lsb_release -cs) \
                   stable"
                sudo apt-get -y update
                sudo apt-get -y install docker docker.io
                sudo apt-get -y install postgresql-client
                sudo systemctl start docker
                sudo systemctl enable docker
                git clone https://github.com/mfieldhouse/docker-php-helloworld.git
                sudo docker build -t docker-php-helloworld docker-php-helloworld/
                sudo docker run  -d -p 80:80 --restart always --name web docker-php-helloworld
                EOF
}

#Creating And Allocate Eip to EC2
resource "aws_eip" "web_ec2" {
  vpc = true

  instance                  = "${aws_instance.web_server.id}"
  associate_with_private_ip = "10.0.3.40"
}


#Creating Security Group For RDS Instance
resource "aws_security_group" "mydb1" {
  name = "mydb1"

  description = "RDS postgres servers (terraform-managed)"
  vpc_id      = "${aws_vpc.custom_vpc.id}"

  # Only postgres in
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Creating RDS Server
resource "aws_db_instance" "default" {
  allocated_storage      = "10"
  engine                 = "postgres"
  engine_version         = "11.6"
  instance_class         = "db.t3.micro"
  name                   = "custom_db"
  username               = "custom_admin"
  password               = "qweR543789"
  db_subnet_group_name   = "${aws_db_subnet_group.default.id}"
  vpc_security_group_ids = ["${aws_security_group.mydb1.id}"]
}

# Creating db subnet group
resource "aws_db_subnet_group" "default" {
  name        = "main_subnet_group"
  description = "Our main group of subnets"
  subnet_ids  = ["${aws_subnet.private1.id}", "${aws_subnet.private2.id}"]
}
