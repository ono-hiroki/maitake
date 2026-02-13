variable "prefix" {
  description = "リソース名のプレフィックス"
  type        = string
  default     = "network-basic"
}

variable "location" {
  description = "Azureリージョン"
  type        = string
  default     = "Japan West"
}

variable "tags" {
  description = "リソースに付与するタグ"
  type        = map(string)
  default = {
    environment = "sandbox"
    managed_by  = "terraform"
  }
}
