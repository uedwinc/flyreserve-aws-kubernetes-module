provider "aws" {
  region = var.aws_region
}

locals {
  cluster_name = "${var.cluster_name}-${var.env_name}"
}

# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster

resource "aws_iam_role" "flyreserve-role" {
  name = local.cluster_name

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "flyreserve-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.flyreserve-role.name
}

resource "aws_security_group" "flyreserve-sg" {
  name        = local.cluster_name
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flyreserve"
  }
}

resource "aws_eks_cluster" "flyreserve-cluster" {
  name     = local.cluster_name
  role_arn = aws_iam_role.flyreserve-role.arn

  vpc_config {
    security_group_ids = [aws_security_group.flyreserve-sg.id]
    subnet_ids         = var.cluster_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.flyreserve-AmazonEKSClusterPolicy
  ]
}

# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EKS Node Group to launch worker nodes

## Node role
resource "aws_iam_role" "flyreserve-node" {
  name = "${local.cluster_name}-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

## Node policy
resource "aws_iam_role_policy_attachment" "flyreserve-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.flyreserve-node.name
}

resource "aws_iam_role_policy_attachment" "flyreserve-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.flyreserve-node.name
}

resource "aws_iam_role_policy_attachment" "flyreserve-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.flyreserve-node.name
}

resource "aws_eks_node_group" "flyreserve-node-group" {
  cluster_name    = aws_eks_cluster.flyreserve-cluster.name
  node_group_name = "flyreserve"
  node_role_arn   = aws_iam_role.flyreserve-node.arn
  subnet_ids      = var.nodegroup_subnet_ids

  scaling_config {
    desired_size = var.nodegroup_desired_size
    max_size     = var.nodegroup_max_size
    min_size     = var.nodegroup_min_size
  }

  disk_size      = var.nodegroup_disk_size
  instance_types = var.nodegroup_instance_types

  depends_on = [
    aws_iam_role_policy_attachment.flyreserve-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.flyreserve-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.flyreserve-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

# Create a kubeconfig file based on the cluster that has been created
resource "local_file" "kubeconfig" {
  content  = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${aws_eks_cluster.flyreserve-cluster.certificate_authority[0].data}
    server: ${aws_eks_cluster.flyreserve-cluster.endpoint}
  name: ${aws_eks_cluster.flyreserve-cluster.arn}
contexts:
- context:
    cluster: ${aws_eks_cluster.flyreserve-cluster.arn}
    user: ${aws_eks_cluster.flyreserve-cluster.arn}
  name: ${aws_eks_cluster.flyreserve-cluster.arn}
current-context: ${aws_eks_cluster.flyreserve-cluster.arn}
kind: Config
preferences: {}
users:
- name: ${aws_eks_cluster.flyreserve-cluster.arn}
  user:
    exec:
      apiVersion: "client.authentication.k8s.io/v1beta1"
      command: aws
      args:
      - eks
      - get-token
      - --region
      - "${var.aws_region}"
      - --cluster-name
      - "${aws_eks_cluster.flyreserve-cluster.name}"
    KUBECONFIG
  filename = "kubeconfig"
}