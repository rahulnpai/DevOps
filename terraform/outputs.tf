output "app_namespace" {
  description = "Kubernetes namespace for the app"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "app_service_name" {
  description = "Kubernetes service name"
  value       = kubernetes_service.app.metadata[0].name
}

output "app_node_port" {
  description = "NodePort exposed for the app"
  value       = 30080
}

output "hpa_name" {
  description = "HPA resource name"
  value       = kubernetes_horizontal_pod_autoscaler_v2.app.metadata[0].name
}

output "monitoring_namespace" {
  description = "Monitoring namespace"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}
