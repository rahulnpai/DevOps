# ══════════════════════════════════════════════════════════════════════════════
#  DevOps MCA Project — Kubernetes Infrastructure via Terraform
#  Mirrors AWS EKS + ECR production pattern on local minikube
# ══════════════════════════════════════════════════════════════════════════════

# ── Namespaces ─────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace
    labels = {
      name        = var.namespace
      env         = "production"
      managed-by  = "terraform"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
    labels = {
      name       = var.monitoring_namespace
      managed-by = "terraform"
    }
  }
}

# ── Deployment ─────────────────────────────────────────────────────────────────
resource "kubernetes_deployment" "app" {
  depends_on = [kubernetes_namespace.app]

  metadata {
    name      = var.app_name
    namespace = var.namespace
    labels = {
      app        = var.app_name
      version    = var.app_version
      managed-by = "terraform"
    }
  }

  spec {
    replicas               = var.app_replicas
    revision_history_limit = 5

    selector {
      match_labels = { app = var.app_name }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "1"
        max_unavailable = "0"
      }
    }

    template {
      metadata {
        labels = { app = var.app_name, version = var.app_version }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/path"   = "/metrics"
          "prometheus.io/port"   = "8000"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 1001
          fs_group        = 1001
        }

        termination_grace_period_seconds = 30

        container {
          name              = "app"
          image             = var.app_image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 8000
            protocol       = "TCP"
          }

          env {
            name  = "APP_ENV"
            value = "production"
          }
          env {
            name  = "WORKERS"
            value = "2"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/live"
              port = 8000
            }
            initial_delay_seconds = 15
            period_seconds        = 20
            failure_threshold     = 3
            timeout_seconds       = 5
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            failure_threshold     = 3
            timeout_seconds       = 3
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "tmp-dir"
            mount_path = "/tmp"
          }
        }

        volume {
          name      = "tmp-dir"
          empty_dir {}
        }
      }
    }
  }
}

# ── Service ────────────────────────────────────────────────────────────────────
resource "kubernetes_service" "app" {
  depends_on = [kubernetes_namespace.app]

  metadata {
    name      = "${var.app_name}-service"
    namespace = var.namespace
    labels    = { app = var.app_name }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "8000"
    }
  }

  spec {
    type = "NodePort"
    selector = { app = var.app_name }

    port {
      name        = "http"
      port        = 8000
      target_port = 8000
      node_port   = 30080
      protocol    = "TCP"
    }
  }
}

# ── HPA ────────────────────────────────────────────────────────────────────────
resource "kubernetes_horizontal_pod_autoscaler_v2" "app" {
  depends_on = [kubernetes_deployment.app]

  metadata {
    name      = "${var.app_name}-hpa"
    namespace = var.namespace
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = var.app_name
    }

    min_replicas = 2
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 60
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}

# ── Prometheus via Helm ────────────────────────────────────────────────────────
resource "helm_release" "prometheus" {
  depends_on = [kubernetes_namespace.monitoring]

  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "58.2.2"
  namespace        = var.monitoring_namespace
  create_namespace = false
  timeout          = 600

  values = [file("${path.module}/../monitoring/prometheus-values.yaml")]
}

# ── Grafana via Helm ───────────────────────────────────────────────────────────
resource "helm_release" "grafana" {
  depends_on = [helm_release.prometheus]

  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  version          = "7.3.9"
  namespace        = var.monitoring_namespace
  create_namespace = false
  timeout          = 300

  set {
    name  = "adminPassword"
    value = var.grafana_admin_password
  }

  values = [file("${path.module}/../monitoring/grafana-values.yaml")]
}
