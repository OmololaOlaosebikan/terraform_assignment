variable "region" {
    description = "AWS region"
    default     = "eu-west-1"
}

variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
    description = "CIDR block for the public subnet"
    default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_availability_zone" {
    description = "Availability zone for the public subnet"
    default     = ["eu-west-1a", "eu-west-1b"]
}

variable "private_subnet_cidr" {
    description = "CIDR block for the private subnet"
    default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "private_subnet_availability_zone" {
    description = "Availability zone for the private subnet"
    default     = ["eu-west-1a", "eu-west-1b"]
}

variable "db_username" {
    description = "Username for the RDS instance"
    default     = "mydbinstance"
}

variable "db_password" {
    description = "Password for the RDS instance"
    default     = "mydbinstance"
}

variable "keyname" {
    description = "Name of AWS key pair"
    default     = "cba_keypair"
}