variable "namespace" {
  description = "Namespace for resources"
  type        = string
  default     = "tf-advanced"
}

variable "replicas" {
  description = "Number of Nginx replicas"
  type        = number
  default     = 2
}

variable "nginx_image" {
  description = "Docker image for Nginx"
  type        = string
  default     = "nginx:1.25-alpine"
}

variable "service_type" {
  description = "K8s service type"
  type        = string
  default     = "NodePort"
}

variable "service_port" {
  description = "Service port"
  type        = number
  default     = 80
}

variable "enable_ingress" {
  description = "Whether to create ingress"
  type        = bool
  default     = false
}

variable "ingress_class" {
  description = "Ingress controller class (e.g., nginx)"
  type        = string
  default     = "nginx"
}

variable "domain" {
  description = "Domain for ingress"
  type        = string
  default     = "example.local"
}

variable "cluster_issuer" {
  description = "Cluster issuer for cert-manager"
  type        = string
  default     = "letsencrypt-http01"
}
