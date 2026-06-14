variable "project_id" {
  description = "デプロイ先の GCP プロジェクト ID"
  type        = string
}

variable "region" {
  description = "リージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "env" {
  description = "環境識別子（リソース名の接頭辞）"
  type        = string
  default     = "sbx"
}

variable "name" {
  description = "リソース名のベース（env と組み合わせる）"
  type        = string
  default     = "demo"
}

variable "github_owner" {
  description = "受け入れる GitHub の owner（org またはユーザー名）。なりすまし防止の条件に使う"
  type        = string
}

variable "github_repository" {
  description = "SA の impersonate を許可するリポジトリ（owner/repo 形式）"
  type        = string
}
