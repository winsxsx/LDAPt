provider "aws" {
    region = "us-east-1"
}

data "aws_vpc" "default" {
	default = true
}

data "aws_subnet_ids" "all" {
	vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group" "allow_22" {
	name = "allow_22"
	vpc_id = data.aws_vpc.default.id
	
	ingress {
		from_port   = 22
		to_port     = 22
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

resource "aws_security_group" "allow_65535" {
	name = "allow_65535"
	vpc_id = data.aws_vpc.default.id
	
	ingress {
	  from_port   = 0
	  to_port     = 65535
          protocol    = "tcp"
	  cidr_blocks = [data.aws_vpc.default.cidr_block]
	}
}



resource "aws_security_group" "allow_80" {
	name = "allow_80"
	vpc_id = data.aws_vpc.default.id

	ingress {
	  from_port   = 80
	  to_port     = 80
	  protocol    = "tcp"
	  cidr_blocks = ["0.0.0.0/0"]
	}
}

resource "aws_instance" "ldap-server" {
	ami           = "ami-0742b4e673072066f"
	instance_type = "t1.micro"
	tags = {
    		Name = "ldap-server"
  	}
  	key_name = "abelski-key"
	vpc_security_group_ids = [aws_security_group.allow_65535.id, aws_security_group.allow_22.id, aws_security_group.allow_80.id]

        connection {
                type = "ssh"
                host = self.public_ip
                user = "ec2-user"
                private_key = file("~/.ssh/abelski-key.pem")
        }

	provisioner "file" {

		source = "server-provision.sh"
		destination = "/tmp/server-provision.sh"
	}

        provisioner "file" {

                source = "ldif"
                destination = "/tmp"
        }


	provisioner "remote-exec" {
		inline = [
			"chmod +x /tmp/server-provision.sh",
			"sudo /tmp/server-provision.sh",
		]
	}
}

resource "aws_instance" "ldap-client" {
        ami           = "ami-0742b4e673072066f"
        instance_type = "t1.micro"
        tags = {
                Name = "ldap-client"
        }
        key_name = "abelski-key"
        vpc_security_group_ids = [aws_security_group.allow_22.id, aws_security_group.allow_65535.id]

        connection {
                type = "ssh"
                host = self.public_ip
                user = "ec2-user"
                private_key = file("~/.ssh/abelski-key.pem")
        }

        provisioner "remote-exec" {
                inline = [
                        "sudo yum -y install openldap-clients nss-pam-ldapd",
      			"sudo authconfig --enableldap --enableldapauth --ldapserver=${aws_instance.ldap-server.private_ip} --ldapbasedn='dc=devopslab,dc=com' --enablemkhomedir --updateall",
			"sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config",
			"sudo systemctl restart sshd",
			"sudo systemctl restart nslcd"
                ]
        }
}


