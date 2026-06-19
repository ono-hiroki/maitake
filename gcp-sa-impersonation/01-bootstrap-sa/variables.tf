variable "project_id" {
  description = "自分の GCP プロジェクト ID に置き換える"
  type        = string
  default     = "my-sandbox"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "runner_sa_id" {
  description = "terraform 実行用 SA の account_id（@より前）"
  type        = string
  default     = "lab-tf-runner"
}

variable "runner_sa_roles" {
  description = "SA に付与するプロジェクトロール。02 でバケットを作るので storage.admin。"
  type        = list(string)
  default     = ["roles/storage.admin"]
}

variable "token_creator_member" {
  description = "この SA を impersonate してよい人。user:メール 形式。自分のメールに置き換える。"
  type        = string
  default     = "user:you@example.com"
}
