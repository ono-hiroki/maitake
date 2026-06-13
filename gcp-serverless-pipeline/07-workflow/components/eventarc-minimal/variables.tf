variable "project_id" {
  description = "GCP プロジェクト ID"
  type        = string
}

variable "region" {
  description = "リージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "name" {
  description = "リソース名のベース"
  type        = string
  default     = "min-eventarc"
}
