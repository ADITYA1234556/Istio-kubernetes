data "aws_ami" "latest_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["amazon"]
}

# control plane
resource "aws_instance" "demo-k8s-aws-alb-master-node" {
  ami           = data.aws_ami.latest_ami.id
  instance_type = var.cluster_node_type
  iam_instance_profile = aws_iam_instance_profile.demo-k8s-aws-alb-iam-profile.name
  source_dest_check = false
  key_name      = var.key_pair
  vpc_security_group_ids = [
    aws_security_group.demo-k8s-aws-alb-sg.id
  ]
  subnet_id = module.demo-k8s-aws-alb-vpc.private_subnets[0]
  root_block_device {
    volume_size = var.volume_size
  }
  tags =  merge(var.tags, {
    Name = var.master_node_name
} )
}

#worker nodes
resource "aws_instance" "demo-k8s-aws-alb-worker-node" {
  for_each      = toset(var.worker_nodes_names)
  ami           = data.aws_ami.latest_ami.id
  iam_instance_profile = aws_iam_instance_profile.demo-k8s-aws-alb-iam-profile.name
  source_dest_check = false
  instance_type = var.cluster_node_type
  key_name      = var.key_pair
  vpc_security_group_ids = [
    aws_security_group.demo-k8s-aws-alb-sg.id
  ]
  subnet_id = module.demo-k8s-aws-alb-vpc.private_subnets[1]
  root_block_device {
    volume_size = var.volume_size
  }
  tags =  merge(var.tags, {
    Name = each.key
} )
}

#Bastian Host
resource "aws_instance" "demo-k8s-aws-alb-bastian-node" {
  ami           = data.aws_ami.latest_ami.id
  instance_type = var.bastian_instance_type
  key_name      = var.key_pair
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.demo-bastian-sg.id
  ]
  subnet_id = module.demo-k8s-aws-alb-vpc.public_subnets[0]
  root_block_device {
    volume_size = var.volume_size
  }
  tags =  merge(var.tags, {
    Name = var.bastian_host_name
} )
}

output "CONTROL_PLANE_IP" {
  value = aws_instance.demo-k8s-aws-alb-master-node.private_ip
  description = "Private IP address of the master node"
}
output "WORKER_NODES_IPs" {
  value = {
    for key, instance in aws_instance.demo-k8s-aws-alb-worker-node :
    key => instance.private_ip
  }
  description = "Private IP addresses of the worker nodes"
}

output "BASTIAN_IP" {
  value = aws_instance.demo-k8s-aws-alb-bastian-node.public_ip
  description = "Private IP address of the master node"
}

output "CONTROL_PLANE_ID" {
  value = aws_instance.demo-k8s-aws-alb-master-node.id
  description = "Private IP address of the master node"
}
output "WORKER_NODES_IDs" {
  value = {
    for key, instance in aws_instance.demo-k8s-aws-alb-worker-node :
    key => instance.id
  }
  description = "Private IP addresses of the worker nodes"
}

output "BASTIAN_ID" {
  value = aws_instance.demo-k8s-aws-alb-bastian-node.id
  description = "Private IP address of the master node"
}