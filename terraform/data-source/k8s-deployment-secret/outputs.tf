output "secret_used" {
  description = "The Secret name read by data source"
  value       = data.kubernetes_secret.db.metadata[0].name
}

output "service_type" {
  value = kubernetes_service.app.spec[0].type
}

output "node_port" {
  description = "NodePort (only meaningful if Service type = NodePort)"
  value       = kubernetes_service.app.spec[0].port[0].node_port
}

output "hint" {
  value = "If NodePort, access via http://<NodeIP>:${kubernetes_service.app.spec[0].port[0].node_port}"
}
