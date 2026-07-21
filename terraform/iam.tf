################################################################################
# Service Accounts for Managed Kubernetes
################################################################################

resource "yandex_iam_service_account" "k8s_cluster" {
  name        = "devops-k8s-cluster-sa"
  description = "Service account for Managed Kubernetes cluster"
}

resource "yandex_iam_service_account" "k8s_nodes" {
  name        = "devops-k8s-nodes-sa"
  description = "Service account for Managed Kubernetes node group"
}

################################################################################
# Cluster SA roles
################################################################################

resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_agent" {
  folder_id = var.yc_folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_vpc_admin" {
  folder_id = var.yc_folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_load_balancer" {
  folder_id = var.yc_folder_id
  role      = "load-balancer.admin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_alb_editor" {
  folder_id = var.yc_folder_id
  role      = "alb.editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_certificate_manager" {
  folder_id = var.yc_folder_id
  role      = "certificate-manager.certificates.downloader"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

################################################################################
# Node SA roles
################################################################################

resource "yandex_resourcemanager_folder_iam_member" "k8s_nodes_puller" {
  folder_id = var.yc_folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_nodes.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_nodes_viewer" {
  folder_id = var.yc_folder_id
  role      = "viewer"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_nodes.id}"
}

# IAM bindings can take up to ~30s to propagate before cluster creation
resource "time_sleep" "wait_for_iam" {
  create_duration = "30s"

  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_cluster_agent,
    yandex_resourcemanager_folder_iam_member.k8s_vpc_admin,
    yandex_resourcemanager_folder_iam_member.k8s_load_balancer,
    yandex_resourcemanager_folder_iam_member.k8s_alb_editor,
    yandex_resourcemanager_folder_iam_member.k8s_certificate_manager,
    yandex_resourcemanager_folder_iam_member.k8s_nodes_puller,
    yandex_resourcemanager_folder_iam_member.k8s_nodes_viewer,
  ]
}
