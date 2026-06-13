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
  description = "環境識別子（リソース名の接頭辞に使う）"
  type        = string
  default     = "sbx"
}

variable "vpc_name" {
  description = "VPC の名前（env と組み合わせて使う）"
  type        = string
  default     = "demo"
}

variable "subnet_cidr" {
  description = "サブネットの CIDR 範囲"
  type        = string
  default     = "10.0.0.0/24"
}
