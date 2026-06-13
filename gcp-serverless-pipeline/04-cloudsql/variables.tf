variable "project_id" {
  description = "デプロイ先の GCP プロジェクト ID"
  type        = string
}

variable "region" {
  description = "リソースを作成するリージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "env" {
  description = "環境識別子（リソース名の接頭辞）"
  type        = string
  default     = "sbx"
}

variable "vpc_name" {
  description = "このモジュールで作成する VPC 名（01-network と衝突しないよう別名）"
  type        = string
  default     = "demo-sql"
}

variable "instance_name" {
  description = "Cloud SQL インスタンス名（env と組み合わせる）"
  type        = string
  default     = "demo"
}

variable "database_name" {
  description = "作成する論理データベース名"
  type        = string
  default     = "demo"
}

variable "db_user" {
  description = "作成する DB ユーザー名"
  type        = string
  default     = "demo_app"
}

variable "db_password_placeholder" {
  description = <<-EOT
    初回 apply 用のダミーパスワード。本物は apply 後に gcloud で手動投入する。
    google_sql_user は lifecycle.ignore_changes で password を追跡しないため、
    本物のパスワードは tfstate に入らない（実運用構成と同じ方式）。
  EOT
  type        = string
  default     = "CHANGE_ME_AFTER_APPLY"
  sensitive   = true
}
