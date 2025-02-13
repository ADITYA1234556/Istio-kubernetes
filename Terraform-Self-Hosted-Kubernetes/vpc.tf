data "aws_availability_zones" "available" {
state = "available"
}

module "demo-k8s-aws-alb-vpc" {
source = "terraform-aws-modules/vpc/aws"
version = "5.17.0"

name = var.vpc_name
cidr = var.cidr_block

azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
private_subnets = [cidrsubnet(var.cidr_block, 8, 110), cidrsubnet(var.cidr_block, 8, 120)]
public_subnets  = [cidrsubnet(var.cidr_block, 8, 10), cidrsubnet(var.cidr_block, 8, 20)]

create_igw = true # Default is true

enable_dns_hostnames = true # Default is true

# nat_gateway configuration
enable_nat_gateway = true
single_nat_gateway = true
one_nat_gateway_per_az = false

create_private_nat_gateway_route = true # Default is true

tags = var.tags
public_subnet_tags = var.public_subnet_tags
}

resource "aws_security_group" "demo-k8s-aws-alb-sg" {
  vpc_id = module.demo-k8s-aws-alb-vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [aws_security_group.demo-bastian-sg.id]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "demo-bastian-sg" {
  vpc_id = module.demo-k8s-aws-alb-vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



