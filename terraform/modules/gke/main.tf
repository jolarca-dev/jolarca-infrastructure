# modules/gke — Private GKE cluster for the 10% GCP plane.
# Non-negotiables from modules/gke/README.md:
# - Private nodes (no public IPs — no-public-ips.rego)
# - Workload Identity enabled
# - Default compute SA DISABLED
# - Network policy with default-deny
# - Release channel pinned
# - database_encryption for application-layer secrets (require-cmek.rego)

resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = "${var.environment}-cluster"
  location = var.region

  # Private cluster — no public IPs on nodes (no-public-ips.rego)
  networking_mode = "VPC_NATIVE"
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  # Master authorized networks — only WireGuard gateway and operator IPs
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_cidrs
      content {
        cidr_block   = cidr_blocks.value.cidr
        display_name = cidr_blocks.value.name
      }
    }
  }

  # VPC-native networking with alias IPs
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Workload Identity — mandatory for secure workload authentication
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Node config for the default node pool (removed immediately)
  node_config {
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  # Network policy (Calico) — default-deny
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
    dns_cache_config {
      enabled = true
    }
  }

  # Application-layer secrets encryption (require-cmek.rego)
  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.gke_secrets.id
  }

  # Release channel — pinned for predictability
  release_channel {
    channel = var.release_channel
  }

  # Logging and monitoring
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "DEPLOYMENT", "POD", "DAEMONSET", "HPA"]
    managed_prometheus {
      enabled = true
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # Maintenance window — EU business hours
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Remove default node pool; we manage our own below
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = var.environment == "production" ? true : false

  resource_labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ── Node pool ────────────────────────────────────────────────────────────

resource "google_container_node_pool" "primary" {
  project  = var.project_id
  name     = "primary"
  cluster  = google_container_cluster.this.name
  location = var.region

  initial_node_count = var.node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"

    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      environment = var.environment
      pool        = "primary"
    }

    tags = [
      "${var.environment}-gke-node",
      "${var.environment}-app",
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = var.release_channel != "UNSPECIFIED"
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# ── Node service account ────────────────────────────────────────────────

resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "${var.environment}-gke-nodes"
  display_name = "GKE node service account (${var.environment})"
}

# Minimal IAM: no basic roles (no-basic-iam-roles.rego)
resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ── KMS for application-layer secrets ────────────────────────────────────

resource "google_kms_key_ring" "gke" {
  project  = var.project_id
  name     = "${var.environment}-gke"
  location = var.region
}

resource "google_kms_crypto_key" "gke_secrets" {
  name     = "${var.environment}-gke-secrets"
  key_ring = google_kms_key_ring.gke.id
  purpose  = "ENCRYPT_DECRYPT"
}

# Grant GKE service agent access to the encryption key
resource "google_kms_crypto_key_iam_member" "gke_encrypt" {
  crypto_key_id = google_kms_crypto_key.gke_secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
}

data "google_project" "current" {
  project_id = var.project_id
}
