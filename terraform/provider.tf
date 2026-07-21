provider "yandex" {
  service_account_key_file = var.yc_service_account_key_file
  cloud_id                 = var.yc_cloud_id
  folder_id                = var.yc_folder_id
  zone                     = var.yc_zone
}

data "yandex_vpc_network" "default" {
  name = "default"
}

data "yandex_vpc_subnet" "default" {
  name = "default-${var.yc_zone}"
}
