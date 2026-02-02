variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
}

variable "vpc_name" {
  description = "VPCのName tag"
  type        = string
}

variable "public_subnets" {
  description = "パブリックサブネットの定義"
  type = map(object({
    cidr = string
    az   = string
    name = string
  }))
}
