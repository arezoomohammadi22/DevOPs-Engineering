output "nginx_namespace" {
  value = kubernetes_namespace.example.metadata[0].name
}

output "nginx_service_type" {
  value = kubernetes_service.nginx.spec[0].type
}

output "nginx_service_nodeport" {
  value       = kubernetes_service.nginx.spec[0].port[0].node_port
  description = "NodePort assigned to Nginx (if service_type=NodePort)"
}

output "nginx_ingress_url" {
  value       = var.enable_ingress ? "https://${var.domain}" : "Ingress disabled"
  description = "Ingress URL if enabled"
}
