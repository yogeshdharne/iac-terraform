# iac-terraform
Terraform Project

# Add AWS Access and Secret Key
Add your aws iam user access and secret key in below parameter.

access_key = ""
secret_key = ""

# your ssh user public key 
Add your ssh user public key in below parameter
resource "aws_key_pair" "auth" {
  key_name   = "mytestpubkey"
  public_key = ""
}

# RDS User Password
Add RDS user password in below parameter.
resource "aws_db_instance" "default" {
  allocated_storage      = "10"
  engine                 = "postgres"
  engine_version         = "11.6"
  instance_class         = "db.t3.micro"
  name                   = "custom_db"
  username               = "custom_admin"
  password               = ""
  db_subnet_group_name   = "${aws_db_subnet_group.default.id}"
  vpc_security_group_ids = ["${aws_security_group.mydb1.id}"]
}

#Usage
Install Teraform and Rune Below Command.

terraform init
terraform apply 

