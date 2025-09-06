variable "namespace" {
  description = "Namespace for resources"
  type        = string
  default     = "tf-demo"
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
