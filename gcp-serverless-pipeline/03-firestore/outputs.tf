output "database_name" {
  description = "Firestore データベース名"
  value       = google_firestore_database.main.name
}

output "database_id" {
  description = "Firestore データベースの完全な ID"
  value       = google_firestore_database.main.id
}

output "location" {
  description = "データベースの location"
  value       = google_firestore_database.main.location_id
}
