variable "container_name" {
  type        = string
  description = "Name of the container"
}

variable "external_port" {
  type        = number
  description = "External port to expose"
}

variable "image" {
  type        = string
  default     = "nginx:1.25-alpine"
}
