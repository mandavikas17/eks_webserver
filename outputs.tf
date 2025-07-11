output "cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = module.eks_cluster.cluster_endpoint
}

output "kubeconfig" {
  description = "Kubeconfig for the EKS cluster"
  value       = module.eks_cluster.kubeconfig
  sensitive   = true # Mark as sensitive
}

output "nginx_service_url" {
  description = "URL of the Nginx LoadBalancer service"
  value       = kubernetes_service.nginx_service.status[0].load_balancer[0].ingress[0].hostname
}
