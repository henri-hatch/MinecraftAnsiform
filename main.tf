variable "region" {
  default = "us-east-1"
}

variable "amis" {
  type = map(string)
  default = {
    "us-east-1" = "ami-00068cd7555f543d5"
    "us-east-2" = "ami-4b32be2b"
  }
}

provider "aws" {
  region = var.region
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 25565
    to_port   = 25565
    protocol  = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "minecraftserver" {
  ami                  = var.amis[var.region]
  instance_type        = "t2.small"
  iam_instance_profile = "s3AdminAccess"
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
      "sudo amazon-linux-extras install epel-release -y",
      "sudo amazon-linux-extras install ansible2 -y"
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