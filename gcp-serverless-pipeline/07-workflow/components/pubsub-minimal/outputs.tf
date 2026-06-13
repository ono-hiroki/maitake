output "topic" {
  description = "作成したトピック名"
  value       = google_pubsub_topic.main.name
}

output "subscription" {
  description = "作成したサブスクリプション名"
  value       = google_pubsub_subscription.main.name
}
