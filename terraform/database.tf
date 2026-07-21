################################################################################
# Managed PostgreSQL (outside Kubernetes)
################################################################################

resource "yandex_mdb_postgresql_cluster" "app_db" {
  name        = "devops-db-cluster"
  environment = "PRESTABLE"
  network_id  = data.yandex_vpc_network.default.id

  security_group_ids = [
    yandex_vpc_security_group.pgsql.id
  ]

  config {
    version = "15"

    resources {
      resource_preset_id = "s2.micro"
      disk_size          = 20
      disk_type_id       = "network-hdd"
    }
  }

  host {
    zone             = var.yc_zone
    subnet_id        = data.yandex_vpc_subnet.default.id
    assign_public_ip = false
  }
}

resource "yandex_mdb_postgresql_user" "app_user" {
  cluster_id = yandex_mdb_postgresql_cluster.app_db.id
  name       = "user1"
  password   = var.db_password
}

resource "yandex_mdb_postgresql_database" "app_db" {
  cluster_id = yandex_mdb_postgresql_cluster.app_db.id
  name       = "db1"
  owner      = yandex_mdb_postgresql_user.app_user.name

  depends_on = [
    yandex_mdb_postgresql_user.app_user
  ]
}
