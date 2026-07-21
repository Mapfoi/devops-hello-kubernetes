provider "yandex" {
  # Auth: path to authorized key via env YC_SERVICE_ACCOUNT_KEY_FILE
  # https://yandex.cloud/docs/terraform/authentication#service-account-key
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

data "yandex_vpc_network" "default" {
  name = "default"
}

data "yandex_vpc_subnet" "default" {
  name = "default-${var.yc_zone}"
}
