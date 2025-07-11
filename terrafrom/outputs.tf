output "cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = module.eks_cluster.cluster_endpoint
}

output "kubeconfig" {
  description = "Kubeconfig for the EKS cluster"
  value       = module.eks_cluster.kubeconfig
  sensitive   = true # Mark as sensitive
}
