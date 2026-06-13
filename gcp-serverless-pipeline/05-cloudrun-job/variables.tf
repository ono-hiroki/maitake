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
  default     = "demo"
}

variable "image" {
  description = <<-EOT
    Cloud Run Job のコンテナイメージ。
    デフォルトは Google 公式のサンプルJobイメージ（実行すると完了する）。
    本物は Artifact Registry に push した自前イメージ URI を指定する:
      asia-northeast1-docker.pkg.dev/<project>/<repo>/app:latest
  EOT
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/job:latest"
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

variable "max_retries" {
  description = "タスク失敗時の最大リトライ回数"
  type        = number
  default     = 3
}

variable "task_timeout" {
  description = "タスクのタイムアウト"
  type        = string
  default     = "600s"
}

variable "env_vars" {
  description = "Cloud Run Job に渡す環境変数"
  type        = map(string)
  default     = {}
}
