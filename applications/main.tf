terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  backend "local" {}
}

data "terraform_remote_state" "compute" {
  backend = "s3"
  config = {
    bucket = "homelab-tfstate"
    key    = "compute/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_eks_cluster_auth" "main" {
  name = data.terraform_remote_state.compute.outputs.cluster_name
}

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.compute.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.compute.outputs.cluster_certificate_authority)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.compute.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.compute.outputs.cluster_certificate_authority)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.14.4"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.10.0"
  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  depends_on = [helm_release.cert_manager]
}
