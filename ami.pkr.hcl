packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.0.0"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "git"
}
variable "source_ami" {
  type    = string
  default = "ami-06db4d78cb1d3bbf9" # Ubuntu 22.04 LTS
}

variable "ssh_username" {
  type    = string
  default = "admin"
}

variable "subnet_id" {
  type    = string
  default = "subnet-0063f324cf391fc6e"
}

source "amazon-ebs" "my-ami" {
  region          = "${var.aws_region}"
  ami_name        = "csye6225_${formatdate("YYYY_MM_DD_hh_mm_ss", timestamp())}"
  ami_description = "AMI for nodejs app"
  ami_regions = [
    "us-east-1",
  ]
  profile = "${var.aws_profile}"

  aws_polling {
    delay_seconds = 120
    max_attempts  = 50
  }

  instance_type = "t2.micro"
  source_ami    = "${var.source_ami}"
  ssh_username  = "${var.ssh_username}"
  subnet_id     = "${var.subnet_id}"

  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    volume_size           = 8
    volume_type           = "gp2"
  }
}

build {
  sources = ["source.amazon-ebs.my-ami"]
  provisioner "shell" {
    inline = [
      "sudo apt update",
      "sudo apt install -y mariadb-server",
      "sudo systemctl start mariadb",
      "sudo systemctl enable mariadb",
      "sudo mysql -u root <<EOF",
      "ALTER USER 'root'@'localhost' IDENTIFIED BY 'password';",
      "FLUSH PRIVILEGES;",
      "EOF",
      "sudo apt update",
      "sudo apt install -y nodejs npm",
      "sudo mkdir -p ~/webapp/dist",
      "sudo chmod -R 777 webapp"
    ]
  }
  provisioner "file" {
    source      = fileexists("dist/main.js") ? "dist/main.js" : "/"
    destination = "/home/admin/webapp/main.js"
  }
  provisioner "file" {
    source      = fileexists(".env") ? ".env" : "/"
    destination = "/home/admin/webapp/.env"
  }
  provisioner "file" {
    source      = "./package.json"
    destination = "/home/admin/webapp/package.json"
  }
  provisioner "file" {
    source      = fileexists("Users.csv") ? "Users.csv" : "/"
    destination = "/home/admin/webapp/Users.csv"
  }
  provisioner "shell" {
    inline = [
      "cd ~/webapp && npm install",
      "sudo mv ~/webapp/Users.csv /opt/"
    ]
  }
}