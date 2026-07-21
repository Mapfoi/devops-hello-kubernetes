variable "yc_service_account_key_file" {
  description = "Path to Yandex Cloud service account JSON key file"
  type        = string
}

variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "yc_folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "yc_zone" {
  description = "Availability zone"
  type        = string
  default     = "ru-central1-a"
}

variable "db_password" {
  description = "Managed PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "k8s_version" {
  description = "Kubernetes version for Managed Kubernetes cluster"
  type        = string
  default     = "1.29"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
}

variable "node_initial_size" {
  description = "Initial number of worker nodes"
  type        = number
  default     = 2
}
