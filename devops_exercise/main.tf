provider "aws" {
  region = "us-east-1"  # Update with your desired region
}

resource "null_resource" "ansible_provisioner" {
  triggers = {
    # You can add triggers if needed, e.g., file changes, etc.
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "ansible-playbook docker-deploy.yml"
  }
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "aws_key" {
  key_name = "ssh_key"
  public_key = tls_private_key.key.public_key_openssh
}

# Create a security group
resource "aws_security_group" "docker_sg" {
  name        = "docker-security-group"
  description = "Security group for Docker containers"
  
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
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4000
    to_port     = 4000
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

# AWS resources
resource "aws_instance" "ec2_instance" {
  depends_on = [null_resource.ansible_provisioner]
  ami           = "ami-0c7217cdde317cfec" # replace with your preferred AMI
  instance_type = "t2.micro"
  key_name      = NVirginiakey
  tags = {
    Name = "frontend-backend-instance"
  }

  # Attach the security group to the instance
  vpc_security_group_ids = [aws_security_group.docker_sg.id]
  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = "${file(local_sensitive_file.private_key.filename)}"
    host     = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "hostname",
    ]
  }
}


resource "null_resource" "docker_provisioner" {
  depends_on = [aws_instance.ec2_instance]
  triggers = {
    # You can add triggers if needed, e.g., file changes, etc.
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i inventory.ini install_docker.yml"
  }
}

resource "null_resource" "provision_containers" {
  depends_on = [null_resource.docker_provisioner]
  triggers = {
    # You can add triggers if needed, e.g., file changes, etc.
    always_run = timestamp()
  }
  
  provisioner "local-exec" {
     command = <<-EOF
      ansible-playbook -i inventory.ini -e "aws_public_ip=${aws_instance.ec2_instance.public_ip}" create_containers.yml
    EOF
  }
}
