output "http_url" {
  value = "http://${var.domain}:${var.http_port}"
}

output "https_url" {
  value = "https://${var.domain}:${var.https_port}"
}