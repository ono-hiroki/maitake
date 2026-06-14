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
  description = "Workflow / SA 名"
  type        = string
  default     = "min-workflows"
}
