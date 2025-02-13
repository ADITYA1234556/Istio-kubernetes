variable "region" {
    type = string
    default = "eu-west-2"
    description = "AWS region"
}

variable "cidr_block" {
    type = string
    default = "172.32.0.0/16"
}

variable "vpc_name" {
    type = string
    default = "demo-k8s-aws-alb" 
}

variable "tags" {
    type = map(string)
    default = {
        terraform  = "true"
        demo = "aws-k8s-aws-alb"
    }
    description = "Tags to apply to all resources"
}

variable "master_node_name" {
  default = "control-plane"
}
variable "worker_nodes_names" {
  default = ["worker1", "worker2"]
}
variable "bastian_host_name" {
  default = "bastian-demo-k8s-aws-alb"
}

#provide your key name
variable "key_pair" {
  description = "The name of the key pair to use for EC2 instances"
  default = "adimsi"
  type        = string
}

variable "cluster_node_type" {
type = string
default = "t2.medium" 
}
variable "bastian_instance_type" {
type = string
default = "t2.micro" 
}

variable "volume_size" {
    type = number
    default = 15
}


#lb controller related variables
variable "public_subnet_tags" {
    type = map(string)
    default = {
        "kubernetes.io/role/elb"  = 1
        "kubernetes.io/cluster/kubernetes"	= "owned"
    }
    description = "Tags to apply to all private subnets for lb discovery"
}

variable "disabe_cluster_src_dst_check" {
  type = bool
  default = false
  description = "Disable source destination check for calico/ overlay network"
  
}