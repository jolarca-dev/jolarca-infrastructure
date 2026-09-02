# modules/networking — outputs.

output "network_id" {
  description = "VPC network self-link."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC network name."
  value       = google_compute_network.this.name
}

output "subnet_ids" {
  description = "Map of subnet names to self-links."
  value       = { for k, v in google_compute_subnetwork.private : k => v.id }
}

output "subnet_names" {
  description = "Map of subnet names to names."
  value       = { for k, v in google_compute_subnetwork.private : k => v.name }
}

output "nat_router_name" {
  description = "Cloud NAT router name."
  value       = google_compute_router.nat.name
}
