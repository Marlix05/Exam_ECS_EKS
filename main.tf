// Provider
provider "aws" {
  region = "us-east-1"
}

// création d'un VPC
resource "aws_vpc" "terraform" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "terraform"
  }
}


// création de sous-réseau public
resource "aws_subnet" "subnet-public" {
  vpc_id     = aws_vpc.terraform.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a" 

  tags = {
    Name = "subnet-public"
  }
}
// création du 1er sous-réseau privé
resource "aws_subnet" "subnet-private-1" {
  vpc_id     = aws_vpc.terraform.id
  availability_zone = "us-east-1b" 
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "subnet-private-1"
  }
}
//création d'une gateway
resource "aws_internet_gateway" "gatewayterraform" {
  vpc_id = aws_vpc.terraform.id

  tags = {
    Name = "gatewayterraform"
  }
}

//ajout d'une table de routage dans internet gateway
resource "aws_route_table" "routerraform" {
  vpc_id = aws_vpc.terraform.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gatewayterraform.id
  }

  tags = {
    Name = "routerraform"
  }
}

// Association de la table de routage au sous-réseau public
resource "aws_route_table_association" "sub-public" {
  subnet_id      = aws_subnet.subnet-public.id
  route_table_id = aws_route_table.routerraform.id
}

// Association de la table de routage au premier sous-réseau privé
resource "aws_route_table_association" "sub-private-1" {
  subnet_id      = aws_subnet.subnet-private-1.id
  route_table_id = aws_route_table.routerraform.id
}
// création d'un groupe de sécurité
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.terraform.id



  tags = {
    Name = "allow_tls"
  }
}

//ajout d'une règle entrante HTTP
resource "aws_vpc_security_group_ingress_rule" "allow_rule_HTTP" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0" // depuis n'importe quelle source
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
//ajout d'une règle entrante SSH
resource "aws_vpc_security_group_ingress_rule" "allow_rule_ssh" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0" // depuis n'importe quelle source
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
//ajout d'une entrante règle 6443
resource "aws_vpc_security_group_ingress_rule" "allow_rule_6443" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0" // depuis n'importe quelle source
  from_port         = 6443
  ip_protocol       = "tcp"
  to_port           = 6443
}
//ajout d'une règle 443
resource "aws_vpc_security_group_ingress_rule" "allow_rule_HTTPS" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0" // depuis n'importe quelle source
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
//ajout d'une règle de sortie HTTPS
resource "aws_vpc_security_group_egress_rule" "allow_rule_engr_HTTPS" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0" // depuis n'importe quelle source
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

//Cluster ECS
resource "aws_ecs_cluster" "cluster_ITEM_NAME" {
  name = "cluster_ITEM_NAME"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

//---------------------Instance bloc----------------------
//Paire de clé
resource "aws_key_pair" "my_key" {
  key_name   = "my_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCpk0SxQbE+CzC0uphFZS916BV/ewVCesYl+t09aPKbWkhIeEAA8Z/pDOE66jOk6eZYxl1IbhE4vYVkUxseEjOkA68Yn8x/7QU8mTub2v3ubDuecph80f1T27/JOerZJOL2EPJYv6tcTGna838R0jbsZkoY+/Tk5DxA0cKHNtwZWbTraFoN0kWUQFOU8sG8H6XejdT6Ev7kaPRTVZDc8v9I25p10jAImhxGayiS6lsdytC6/gQMiLoaJMqnyxl+4136mwQ8Y7Ltklb6fajBZtqKZtA503GLzgUhXtoFyK5u0X36qjTn9f7SVDb+lgOLEwrOB75JcOMFu52hHMEXpu2x jenkins@ubuntu"
}

//Création instance master
resource "aws_instance" "master" {
  ami           = "ami-0e1bed4f06a3b463d"
  instance_type = "t2.medium"
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  subnet_id = aws_subnet.subnet-private-1.id
  key_name = aws_key_pair.my_key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "master_node"
  }
  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file("${path.cwd}/id_rsa")
    host     = self.public_ip
  }
  user_data = file("master.sh")
}
//Création instance worker1
resource "aws_instance" "worker1" {
  ami           = "ami-0e1bed4f06a3b463d"
  instance_type = "t2.medium"
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  subnet_id = aws_subnet.subnet-private-1.id
  key_name = aws_key_pair.my_key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "worker1_node"
  }
  user_data = file("worker.sh")
}

//Création instance worker2
resource "aws_instance" "worker2" {
  ami           = "ami-0e1bed4f06a3b463d"
  instance_type = "t2.medium"
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  subnet_id = aws_subnet.subnet-private-1.id
  key_name = aws_key_pair.my_key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "worker2_node"
  }
  user_data = file("worker.sh")
}
//---------------------Cluster bloc-------------------------------------------
/*// création d'un repository
resource "aws_ecr_repository" "rep" {
  name                 = "rep"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
*/
