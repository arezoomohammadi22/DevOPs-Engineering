variable "container_count" {
  description = "تعداد کانتینرهای nginx"
  type        = number
  default     = 2
}

variable "nginx_image" {
  description = "ایمیج Nginx"
  type        = string
  default     = "nginx:latest"
}

variable "http_port_start" {
  description = "اولین پورت خارجی که استفاده می‌شود"
  type        = number
  default     = 8080
}
