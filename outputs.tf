output "eks_cluster_id" {
  value = aws_eks_cluster.flyreserve-cluster.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.flyreserve-cluster.name
}

output "eks_cluster_certificate_data" {
  value = aws_eks_cluster.flyreserve-cluster.certificate_authority[0].data
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.flyreserve-cluster.endpoint
}

output "eks_cluster_nodegroup_id" {
  value = aws_eks_node_group.flyreserve-node-group.id
}

output "kubeconfig" {
  value = local_file.kubeconfig
}