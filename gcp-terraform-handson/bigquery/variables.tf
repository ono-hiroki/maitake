variable "project_id" {
  description = "デプロイ先の GCP プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Dataset を作成する location（リージョン）"
  type        = string
  default     = "asia-northeast1"
}

variable "env" {
  description = "環境識別子（dataset_id の接頭辞）"
  type        = string
  default     = "sbx"
}

variable "dataset_name" {
  description = "データセット名（env と組み合わせる。ハイフンは自動で _ に変換）"
  type        = string
  default     = "demo"
}
