terraform {
  required_version = ">= 1.5.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.85"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}
