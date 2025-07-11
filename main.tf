provider "aws" {
  region = var.aws_region
}


data "aws_eks_cluster" "cluster" {
  name = module.eks_cluster.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.cluster_name
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = {
    mapRoles = yamlencode([
      {
        rolearn  = module.eks_cluster.eks_managed_node_groups["default"].iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      },
    ])
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0" # Use a compatible version

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  enable_dns_hostnames   = true
  enable_dns_support     = true

  tags = {
    Environment = var.environment
  }
}


module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.0.0" # Use a compatible version

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # Worker nodes in private subnets

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      name           = "${var.cluster_name}-nodegroup"
      instance_types = [var.instance_type]
      desired_capacity = var.desired_capacity
      max_capacity     = var.max_capacity
      min_capacity     = var.min_capacity
      disk_size        = 20

      labels = {
        role = "worker"
      }
    }
  }

  tags = {
    Environment = var.environment
  }
}


resource "kubernetes_deployment" "nginx_app" {
  metadata {
    name      = "nginx-deployment"
    namespace = "default"
    labels = {
      app = "nginx"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }
      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
  depends_on = [module.eks_cluster] # Ensure cluster is ready
}

resource "kubernetes_service" "nginx_service" {
  metadata {
    name      = "nginx-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "nginx"
    }
    port {
      protocol    = "TCP"
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer" # Exposes the service via an AWS Classic Load Balancer
  }
  depends_on = [kubernetes_deployment.nginx_app] # Ensure deployment is ready
}
