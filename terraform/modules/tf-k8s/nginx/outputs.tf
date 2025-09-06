output "namespace" {
  value = kubernetes_namespace.this.metadata[0].name
}
