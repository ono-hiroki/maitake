output "network_id" {
  description = "作成した VPC ネットワークの ID"
  value       = google_compute_network.main.id
}

output "network_name" {
  description = "作成した VPC ネットワークの名前"
  value       = google_compute_network.main.name
}

output "subnet_id" {
  description = "作成したサブネットの ID"
  value       = google_compute_subnetwork.main.id
}

output "subnet_cidr" {
  description = "サブネットの CIDR 範囲"
  value       = google_compute_subnetwork.main.ip_cidr_range
}
