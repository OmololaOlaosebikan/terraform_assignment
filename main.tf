provider "aws" {
    region = var.region
}

resource "aws_vpc" "cba_ha_vpc" {
    cidr_block           = var.vpc_cidr
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags = {
        Name = "cba_ha_vpc"
    }
}

resource "aws_internet_gateway" "cba_ha_igw" {
    vpc_id = aws_vpc.cba_ha_vpc.id
}

resource "aws_subnet" "cba_ha_public_subnet" {
    count                   = 2
    vpc_id                  = aws_vpc.cba_ha_vpc.id
    cidr_block              = var.public_subnet_cidr[count.index]
    map_public_ip_on_launch = true
    availability_zone       = var.public_subnet_availability_zone[count.index]
    tags = {
        Name = "cba_ha_public_subnet_${count.index}"
    }
}

resource "aws_subnet" "cba_ha_private_subnet" {
    count                   = 2
    vpc_id                  = aws_vpc.cba_ha_vpc.id
    cidr_block              = var.private_subnet_cidr[count.index]
    map_public_ip_on_launch = true
    availability_zone       = var.private_subnet_availability_zone[count.index]
    tags = {
        Name = "cba_ha_private_subnet_${count.index}"
    }
}

resource "aws_route_table" "cba_ha_public_rtb" {
    vpc_id = aws_vpc.cba_ha_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.cba_ha_igw.id
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id      = aws_internet_gateway.cba_ha_igw.id
    }

    tags = {
        Name = "cba_ha_public_rtb"
    }
}

resource "aws_route_table" "cba_ha_private_rtb" {
    vpc_id = aws_vpc.cba_ha_vpc.id
    count = 2

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.cba_ha_naw[count.index].id
    }

    route {
        ipv6_cidr_block = "::/0"
        nat_gateway_id      = aws_nat_gateway.cba_ha_naw[count.index].id
    }

    tags = {
        Name = "cba_ha_private_rtb"
    }
}

resource "aws_route_table_association" "cba_ha_public_rtb_ass" {
    count          = length(aws_subnet.cba_ha_public_subnet)
    subnet_id      = aws_subnet.cba_ha_public_subnet[count.index].id
    gateway_id     = aws_internet_gateway.cba_ha_igw.id
    route_table_id = aws_route_table.cba_ha_public_rtb.id
}

resource "aws_route_table_association" "cba_ha_private_rtb_ass" {
    count          = length(aws_subnet.cba_ha_private_subnet)
    subnet_id      = aws_subnet.cba_ha_private_subnet[count.index].id
    route_table_id = aws_route_table.cba_ha_private_rtb[count.index].id
}

resource "aws_nat_gateway" "cba_ha_naw" {
    count         = 2
    subnet_id     = aws_subnet.cba_ha_private_subnet[count.index].id

    tags = {
        Name = "cba_ha_naw"
    }
}

resource "aws_elb" "cba-ha-lb-frontend" {
    name                = "cba-ha-lb-frontend"
    availability_zones  = var.public_subnet_availability_zone[*]
    subnets             = aws_subnet.cba_ha_public_subnet[*].id
    internal            = false
    listener {
        instance_port     = 8000
        instance_protocol = "http"
        lb_port           = 80
        lb_protocol       = "http"
    }

    tags = {
        Name = "cba-ha-lb-frontend"
    }
}

resource "aws_elb" "cba-ha-lb-backend" {
    name                = "cba-ha-lb-backend"
    availability_zones  = var.private_subnet_availability_zone[*]
    subnets             = aws_subnet.cba_ha_private_subnet[*].id
    internal            = true
    listener {
        instance_port     = 8000
        instance_protocol = "http"
        lb_port           = 80
        lb_protocol       = "http"
    }

    tags = {
        Name = "cba-ha-lb-backend"
    }
}

resource "aws_security_group" "cba_ha_sg_frontend" {
    name   = "cba_ha_sg_frontend"
    vpc_id = aws_vpc.cba_ha_vpc.id

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

resource "aws_lb_target_group" "cba_ha_lb_frontend_tg" {
    name     = "cba-ha-lb-frontend-tg"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.cba_ha_vpc.id

    health_check {
        enabled             = true
        interval            = 30
        path                = "/health.html"
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
    }
}

resource "aws_lb_target_group" "cba_ha_lb_backend_tg" {
    name     = "cba-ha-lb-backend-tg"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.cba_ha_vpc.id

    health_check {
        enabled             = true
        interval            = 30
        path                = "/health.html"
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
    }
}

resource "aws_autoscaling_group" "cba_ha_asg_frontend" {
    name                      = "cba_ha_asg_frontend"
    max_size                  = 2
    min_size                  = 2
    health_check_grace_period = 200
    desired_capacity          = 2
    launch_template {
        id      = aws_launch_template.cba_ha_lt_backend.id
        version = "$Latest"
    }
}

resource "aws_autoscaling_attachment" "cba_ha_asg_frontend_ass" {
  autoscaling_group_name = aws_autoscaling_group.cba_ha_asg_frontend.id
  elb                    = aws_elb.cba-ha-lb-frontend.id
}

resource "aws_autoscaling_group" "cba_ha_asg_backend" {
    name                      = "cba_ha_asg_backend"
    max_size                  = 2
    min_size                  = 2
    health_check_grace_period = 200
    desired_capacity          = 2
    launch_template {
        id      = aws_launch_template.cba_ha_lt_backend.id
        version = "$Latest"
    }
}

resource "aws_autoscaling_attachment" "cba_ha_asg_backend_ass" {
  autoscaling_group_name = aws_autoscaling_group.cba_ha_asg_backend.id
  elb                    = aws_elb.cba-ha-lb-backend.id
}

resource "aws_launch_template" "cba_ha_lt_frontend" {
    name = "cba_ha_lt_frontend"
    image_id = "ami-09cce85cf54d36b29"
    instance_type = "t2.micro"
}

resource "aws_launch_template" "cba_ha_lt_backend" {
    name = "cba_ha_lt_backend"
    image_id = "ami-09cce85cf54d36b29"
    instance_type = "t2.micro"
}

resource "aws_db_subnet_group" "cba_ha_db_group" {
    name       = "cba_ha_db_group"
    subnet_ids = aws_subnet.cba_ha_private_subnet[*].id
}

resource "aws_db_instance" "cba_ha_db" {
    count             = 1
    allocated_storage = 20
    storage_type      = "gp2"
    engine            = "mysql"
    engine_version    = "5.7"
    instance_class    = "db.t2.micro"
    username             = var.db_username
    password             = var.db_password
    parameter_group_name = "cba_ha_db.mysql5.7"
    db_subnet_group_name = aws_db_subnet_group.cba_ha_db_group.name
    skip_final_snapshot  = true
}

resource "aws_instance" "cba_ha_bastion_host" {
    count         = 2
    ami           = "ami-09cce85cf54d36b29"
    instance_type = "t2.micro"
    key_name      = var.keyname
    subnet_id     = "cba_ha_public_subnet_${count.index}"

    tags = {
        Name = "cba_ha_bastion_host"
    }
}