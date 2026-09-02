# modules/gke — outputs.

output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.this.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint (private IP)."
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate (base64)."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "node_service_account" {
  description = "GKE node service account email."
  value       = google_service_account.gke_nodes.email
}

output "workload_identity_pool" {
  description = "Workload Identity pool."
  value       = "${var.project_id}.svc.id.goog"
}
