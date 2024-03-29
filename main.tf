variable "region" {
  default = "us-east-1"
}

variable "amis" {
  type = map(string)
  default = {
    "us-east-1" = "ami-00eb20669e0990cb4"
    "us-east-2" = "ami-4b32be2b"
  }
}

provider "aws" {
  region = var.region
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.minecraftvpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 25565
    to_port     = 25565
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

resource "aws_vpc" "minecraftvpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "mc_ig" {
  vpc_id = aws_vpc.minecraftvpc.id
}

resource "aws_route_table" "mc_rt" {
  vpc_id = aws_vpc.minecraftvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mc_ig.id
  }
}

resource "aws_subnet" "mc_subnet" {
  vpc_id                  = aws_vpc.minecraftvpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_route_table_association" "mc_rta" {
  subnet_id      = aws_subnet.mc_subnet.id
  route_table_id = aws_route_table.mc_rt.id
}


resource "aws_instance" "minecraftserver" {
  ami                  = var.amis[var.region]
  instance_type        = "t2.small"
  iam_instance_profile = "s3AdminAccess"
  subnet_id            = aws_subnet.mc_subnet.id
  tags = {
    Name = "minecraft"
  }
  key_name               = "minecraftkey"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/Keys/minecraftkey.pem")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum-config-manager --enable epel",
      "sudo yum install ansible -y",
      "sudo yum install java-1.8.0 -y",
      "sudo yum remove java-1.7.0 -y",
      "sudo aws s3 cp s3://minecraft-ansible/ . --recursive",
      "ansible-playbook /home/ec2-user/${var.servertype}server.yml"
    ]
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "aws s3 cp . s3://ansibleminecraftserver/${var.servertype}server --recursive"
    ]
  }
}

resource "aws_route53_record" "minecraft_hatchhome_record" {
  zone_id = "Z1KMSJTSFH7XB"
  name    = "minecraft.hatchhome.com"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.minecraftserver.public_ip]
}