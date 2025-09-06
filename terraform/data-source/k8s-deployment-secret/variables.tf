variable "namespace" {
  description = "Target Kubernetes namespace"
  type        = string
  default     = "default"
}

variable "secret_name" {
  description = "Existing Secret name to read via data source"
  type        = string
  default     = "db-credentials"
}

variable "app_name" {
  description = "App name"
  type        = string
  default     = "k8s-data-vs-resource-demo"
}

variable "image" {
  description = "Container image"
  type        = string
  default     = "nginx:1.25-alpine"
}

variable "service_type" {
  description = "Service type"
  type        = string
  default     = "NodePort" # or ClusterIP / LoadBalancer
}

variable "service_port" {
  description = "Service port"
  type        = number
  default     = 80
}

variable "replicas" {
  description = "Deployment replica count"
  type        = number
  default     = 2
}
