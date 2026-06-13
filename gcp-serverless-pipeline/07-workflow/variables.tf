variable "project_id" {
  description = "デプロイ先の GCP プロジェクト ID"
  type        = string
}

variable "region" {
  description = "リソースを作成するリージョン（バケットとトリガーは同一リージョン）"
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
  default     = "demo-wf"
}

variable "job_image" {
  description = "Workflows から起動する Cloud Run Job のイメージ（既定は公式サンプル）"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/job:latest"
}
