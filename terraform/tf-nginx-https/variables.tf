variable "domain" {
  description = "Domain to serve"
  type        = string
  default     = "sananetco.com"
}

variable "http_port" {
  description = "External HTTP port"
  type        = number
  default     = 80
}

variable "https_port" {
  description = "External HTTPS port"
  type        = number
  default     = 443
}

variable "container_name" {
  description = "Nginx container name"
  type        = string
  default     = "nginx_tls"
}

variable "dev_self_signed_days" {
  description = "Validity of self-signed cert in days"
  type        = number
  default     = 365
}