# IAM is managed manually (once), not by Terraform.
# Service account: hello-k8s-sa (or var.k8s_service_account_name)

data "yandex_iam_service_account" "k8s" {
  name = var.k8s_service_account_name
}
