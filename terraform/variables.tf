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

variable "k8s_service_account_name" {
  description = "Existing IAM service account used by Managed Kubernetes (cluster + nodes). Roles are assigned manually."
  type        = string
  default     = "hello-k8s-sa"
}

variable "db_password" {
  description = "Managed PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "k8s_version" {
  description = "Kubernetes version for Managed Kubernetes cluster"
  type        = string
  default     = "1.35"
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
