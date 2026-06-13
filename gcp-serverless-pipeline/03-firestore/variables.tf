variable "project_id" {
  description = "デプロイ先の GCP プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Database を作成する location（リージョン）"
  type        = string
  default     = "asia-northeast1"
}

variable "env" {
  description = "環境識別子（DB 名の接頭辞）"
  type        = string
  default     = "sbx"
}

variable "db_name" {
  description = "Firestore データベース名（env と組み合わせる）"
  type        = string
  default     = "demo"
}
