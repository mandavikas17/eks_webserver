output "cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = module.eks_cluster.cluster_endpoint
}

# Remove or comment out this block as 'kubeconfig' is not a direct output of the EKS module (v20.x.x)
/*
output "kubeconfig" {
  description = "Kubeconfig for the EKS cluster"
  value       = module.eks_cluster.kubeconfig
  sensitive   = true # Mark as sensitive
}
*/

# Optional: If you want to output the cluster name for verification/debugging
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks_cluster.cluster_id # Or cluster_name, depends on module version/output
}

# Optional: If you specifically need the CA data for custom kubeconfig generation (less common)
output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for the cluster"
  value       = module.eks_cluster.cluster_certificate_authority_data
  sensitive   = true
}
