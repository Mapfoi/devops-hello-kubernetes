################################################################################
# Security Groups
################################################################################

resource "yandex_vpc_security_group" "k8s_main" {
  name        = "devops-k8s-main-sg"
  description = "Security group for Managed Kubernetes cluster"
  network_id  = data.yandex_vpc_network.default.id

  # Allow all internal cluster traffic
  ingress {
    protocol       = "ANY"
    description    = "Intra-cluster communication"
    v4_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  # Kubernetes API
  ingress {
    protocol       = "TCP"
    description    = "Kubernetes API"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  # NodePort range (for LoadBalancer / Ingress backends)
  ingress {
    protocol       = "TCP"
    description    = "NodePort services"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }

  # Health checks from Yandex Load Balancer
  ingress {
    protocol          = "TCP"
    description       = "NLB / ALB health checks"
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }

  # HTTP / HTTPS for Ingress
  ingress {
    protocol       = "TCP"
    description    = "HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTPS"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  egress {
    protocol       = "ANY"
    description    = "Outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "k8s_nodes" {
  name        = "devops-k8s-nodes-sg"
  description = "Security group for Kubernetes worker nodes"
  network_id  = data.yandex_vpc_network.default.id

  ingress {
    protocol          = "ANY"
    description       = "Traffic from cluster SG"
    security_group_id = yandex_vpc_security_group.k8s_main.id
  }

  ingress {
    protocol       = "ANY"
    description    = "Pod / Service CIDR traffic"
    v4_cidr_blocks = ["10.96.0.0/16", "10.112.0.0/16"]
  }

  ingress {
    protocol          = "TCP"
    description       = "Load balancer health checks"
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }

  egress {
    protocol       = "ANY"
    description    = "Outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

################################################################################
# Managed Kubernetes Cluster
################################################################################

resource "yandex_kubernetes_cluster" "app" {
  name        = "devops-k8s-cluster"
  description = "Managed Kubernetes cluster for Flask DevOps application"
  network_id  = data.yandex_vpc_network.default.id

  master {
    version = var.k8s_version
    zonal {
      zone      = var.yc_zone
      subnet_id = data.yandex_vpc_subnet.default.id
    }

    public_ip = true

    security_group_ids = [
      yandex_vpc_security_group.k8s_main.id
    ]

    maintenance_policy {
      auto_upgrade = true

      maintenance_window {
        start_time = "03:00"
        duration   = "3h"
      }
    }
  }

  service_account_id      = data.yandex_iam_service_account.k8s.id
  node_service_account_id = data.yandex_iam_service_account.k8s.id

  release_channel = "REGULAR"

  network_policy_provider = "CALICO"
}
