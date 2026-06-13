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

variable "name" {
  description = "リソース名のベース（env と組み合わせる）"
  type        = string
  default     = "demo-ui"
}

variable "image" {
  description = <<-EOT
    Cloud Run Service のコンテナイメージ。$PORT で待ち受ける必要がある。
    デフォルトは Google 公式サンプル hello イメージ。
    本物は Artifact Registry の自前イメージ URI を指定する。
  EOT
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello:latest"
}

variable "cpu" {
  description = "コンテナの CPU 上限"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "コンテナのメモリ上限"
  type        = string
  default     = "512Mi"
}

variable "iap_members" {
  description = <<-EOT
    IAP 経由でのアクセスを許可する principal のリスト。
    例: ["user:foo@example.com", "group:bar@example.com"]
  EOT
  type        = list(string)
  default     = []
}
