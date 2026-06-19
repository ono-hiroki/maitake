variable "project_id" {
  description = "自分の GCP プロジェクト ID に置き換える（01 と同じ値）"
  type        = string
  default     = "my-sandbox"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}
