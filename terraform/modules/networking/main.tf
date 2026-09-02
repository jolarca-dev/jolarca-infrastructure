# modules/networking — GCP VPC for the 10% plane.
# Creates a VPC with private subnets, Cloud NAT, Private Google Access,
# and firewall rules. Non-negotiables from modules/networking/README.md:
# - Default-deny ingress; allow-list per service pair
# - Private Google Access on all subnets; no public subnets
# - Cloud NAT with optional static egress IPs
# - Flow logs enabled (ISO 27001 A.8.16)

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = "${var.environment}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  # Network is the bridge between GKE and the WireGuard mesh;
  # no public subnets — all compute is private (no-public-ips.rego).
}

# ── Subnets ──────────────────────────────────────────────────────────────

resource "google_compute_subnetwork" "private" {
  for_each = { for idx, subnet in var.subnets : subnet.name => subnet }

  project       = var.project_id
  name          = "${var.environment}-${each.value.name}"
  network       = google_compute_network.this.id
  region        = var.region
  ip_cidr_range = each.value.ip_cidr_range

  private_ip_google_access = true # Private Google Access — mandatory

  # Flow logs for forensic readiness (ISO 27001 A.8.16)
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = each.value.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = each.value.services_cidr
  }
}

# ── Cloud NAT ────────────────────────────────────────────────────────────

resource "google_compute_router" "nat" {
  project = var.project_id
  name    = "${var.environment}-nat-router"
  network = google_compute_network.this.id
  region  = var.region
}

resource "google_compute_router_nat" "this" {
  project                            = var.project_id
  name                               = "${var.environment}-nat"
  router                             = google_compute_router.nat.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ── Firewall rules ───────────────────────────────────────────────────────

# Default deny ingress is implicit in GCP VPCs; we only add explicit allows.

resource "google_compute_firewall" "allow_internal" {
  project = var.project_id
  name    = "${var.environment}-allow-internal"
  network = google_compute_network.this.id

  # Allow all traffic between instances within the VPC
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = concat(
    [for s in var.subnets : s.ip_cidr_range],
    [for s in var.subnets : s.pods_cidr],
    [for s in var.subnets : s.services_cidr],
  )
}

resource "google_compute_firewall" "allow_health_checks" {
  project = var.project_id
  name    = "${var.environment}-allow-health-checks"
  network = google_compute_network.this.id

  # Allow GCP health check ranges (required for load balancer backends)
  allow {
    protocol = "tcp"
    ports    = ["8080", "8443"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["${var.environment}-app"]
}

# WireGuard ingress from the bare-metal mesh (the ONLY bridge, ADR isolation-model.md boundary 2)
resource "google_compute_firewall" "allow_wireguard" {
  project = var.project_id
  name    = "${var.environment}-allow-wireguard"
  network = google_compute_network.this.id

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  source_ranges = var.wireguard_source_ranges
  target_tags   = ["${var.environment}-wg-gateway"]
}
