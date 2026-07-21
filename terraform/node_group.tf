################################################################################
# Kubernetes Node Group (autoscaling 2–5)
################################################################################

resource "yandex_kubernetes_node_group" "workers" {
  cluster_id  = yandex_kubernetes_cluster.app.id
  name        = "devops-k8s-workers"
  description = "Worker node group with autoscaling"
  version     = var.k8s_version

  instance_template {
    platform_id = "standard-v3"

    resources {
      cores         = 2
      memory        = 4
      core_fraction = 50
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

    network_interface {
      nat                = true
      subnet_ids         = [data.yandex_vpc_subnet.default.id]
      security_group_ids = [yandex_vpc_security_group.k8s_nodes.id]
    }

    scheduling_policy {
      preemptible = false
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    auto_scale {
      min     = var.node_min_size
      max     = var.node_max_size
      initial = var.node_initial_size
    }
  }

  allocation_policy {
    location {
      zone = var.yc_zone
    }
  }

  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true

    maintenance_window {
      day        = "monday"
      start_time = "03:00"
      duration   = "3h"
    }
  }

  depends_on = [
    yandex_kubernetes_cluster.app
  ]
}
