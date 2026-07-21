################################################################################
# Security Groups — rules aligned with Yandex Managed Kubernetes docs
# https://yandex.cloud/docs/vpc/concepts/security-groups
################################################################################

resource "yandex_vpc_security_group" "k8s_main" {
  name        = "devops-k8s-main-sg"
  description = "Security group for Managed Kubernetes master"
  network_id  = data.yandex_vpc_network.default.id

  ingress {
    protocol          = "ANY"
    description       = "In-SG communication"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    protocol       = "TCP"
    description    = "Kubernetes API"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    protocol          = "TCP"
    description       = "NLB / ALB health checks"
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }

  # Nodes / pods in VPC (avoids SG circular dependency with k8s_nodes)
  ingress {
    protocol       = "ANY"
    description    = "Traffic from VPC / pod networks"
    v4_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    from_port      = 0
    to_port        = 65535
  }

  egress {
    protocol       = "ANY"
    description    = "Outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

  egress {
    protocol       = "TCP"
    description    = "VM metadata service"
    v4_cidr_blocks = ["169.254.169.254/32"]
    port           = 80
  }
}

resource "yandex_vpc_security_group" "k8s_nodes" {
  name        = "devops-k8s-nodes-sg"
  description = "Security group for Kubernetes worker nodes"
  network_id  = data.yandex_vpc_network.default.id

  ingress {
    protocol          = "ANY"
    description       = "In-SG communication"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    protocol          = "ANY"
    description       = "Master to nodes"
    security_group_id = yandex_vpc_security_group.k8s_main.id
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    protocol       = "ANY"
    description    = "Pod and Service CIDRs"
    v4_cidr_blocks = ["10.96.0.0/16", "10.112.0.0/16"]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    protocol       = "TCP"
    description    = "NodePort services"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTP via Ingress / NLB"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTPS via Ingress / NLB"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    protocol          = "TCP"
    description       = "NLB / ALB health checks"
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }

  egress {
    protocol       = "ANY"
    description    = "Outbound (Docker Hub, MDB, DNS)"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

  egress {
    protocol       = "TCP"
    description    = "VM metadata service"
    v4_cidr_blocks = ["169.254.169.254/32"]
    port           = 80
  }
}

resource "yandex_vpc_security_group" "pgsql" {
  name        = "devops-pgsql-sg"
  description = "Allow PostgreSQL from Kubernetes nodes"
  network_id  = data.yandex_vpc_network.default.id

  ingress {
    protocol          = "TCP"
    description       = "PostgreSQL from K8s nodes"
    port              = 6432
    security_group_id = yandex_vpc_security_group.k8s_nodes.id
  }

  ingress {
    protocol       = "TCP"
    description    = "PostgreSQL from pod CIDR"
    port           = 6432
    v4_cidr_blocks = ["10.112.0.0/16"]
  }

  egress {
    protocol       = "ANY"
    description    = "Outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
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

  release_channel         = "REGULAR"
  network_policy_provider = "CALICO"
}
