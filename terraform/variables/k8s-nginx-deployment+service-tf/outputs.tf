output "nginx_service_nodeport" {
  value = kubernetes_service.nginx.spec[0].port[0].node_port
}
