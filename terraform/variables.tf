variable "kube_context" {
  description = "kubectl context name"
  type        = string
  default     = "minikube"
}

variable "namespace" {
  description = "Kubernetes namespace for the app"
  type        = string
  default     = "devops-prod"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "devops-app"
}

variable "app_image" {
  description = "Full Docker image reference"
  type        = string
  default     = "localhost:5000/devops-mca-app:latest"
}

variable "app_replicas" {
  description = "Initial replica count"
  type        = number
  default     = 2
}

variable "app_version" {
  description = "Application version label"
  type        = string
  default     = "1.0.0"
}

variable "monitoring_namespace" {
  description = "Namespace for Prometheus + Grafana"
  type        = string
  default     = "monitoring"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin123"
}
