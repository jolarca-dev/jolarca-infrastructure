# modules/state-bucket — Terraform state custody infrastructure (ADR-0003).
#
# Provisions, per environment: CMEK keyring/key (90-day rotation), the
# versioned state bucket (uniform access, public access prevented, soft
# delete, optional retention lock), a dedicated state service account with
# least-privilege bindings, optional WIF impersonation for CI, and GCS
# audit logging. Compliance: SOC 2 CC6.6, ISO 27001 A.8.24, GDPR Art. 32.
#
# OPA gates honored: require-cmek.rego (encryption block on any *tfstate*
# bucket), no-basic-iam-roles.rego (curated roles only).

data "google_project" "current" {
  project_id = var.project_id
}

# --- CMEK -------------------------------------------------------------------
# Key custody: environment-scoped keyring + key. Rotation every 90 days;
# destroy window left at the provider default (24h) so a compromised or
# wrongly-issued key can be revoked per docs/runbooks/state-compromise.md.

resource "google_kms_key_ring" "state" {
  project  = var.project_id
  name     = "tfstate-${var.environment}"
  location = var.region

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "state" {
  name            = "tfstate-${var.environment}"
  key_ring        = google_kms_key_ring.state.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s" # 90 days (ISO 27001 A.8.24 key-management cadence)

  lifecycle {
    prevent_destroy = true
  }
}

# GCS performs CMEK envelope encryption as the project's GCS service
# account; it needs encrypterDecrypter on the key (least-privilege, key
# scope only — never key-admin).
resource "google_kms_crypto_key_iam_member" "gcs_service_account" {
  crypto_key_id = google_kms_crypto_key.state.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gs-project-accounts.com"
}

# --- State bucket ------------------------------------------------------------

resource "google_storage_bucket" "state" {
  project       = var.project_id
  name          = var.bucket_name
  location      = var.region
  storage_class = "STANDARD"

  # Uniform bucket-level access: no per-object ACLs, no legacy surprise
  # grants. Public access prevented at the bucket level (defense in depth
  # on top of uniform access).
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Versioned state is the undo lever (terraform/README.md: State recovery).
  versioning {
    enabled = true
  }

  # Access/usage logs ship to the dedicated log bucket below
  # (CKV_GCP_62); Cloud Audit Logs (admin + data access) are enabled
  # project-wide further down — the two layers answer different questions.
  logging {
    log_bucket = google_storage_bucket.state_logs.name
  }

  # CMEK — required by policies/require-cmek.rego for any *tfstate* bucket.
  encryption {
    default_kms_key_name = google_kms_crypto_key.state.id
  }

  # Production doctrine: retention window + irreversible lock. Staging
  # keeps retention_days=0 so soak migrations stay cheap; versioning still
  # protects it.
  dynamic "retention_policy" {
    for_each = var.retention_days > 0 ? [var.retention_days] : []
    content {
      retention_period = retention_policy.value * 86400
      is_locked        = var.lock_retention
    }
  }

  # Soft delete: one more recovery layer against accidental or malicious
  # deletion (ransomware posture, SOC 2 A1.2).
  soft_delete_policy {
    retention_duration_seconds = 604800 # 7 days
  }

  labels = merge(
    {
      environment = var.environment
      purpose     = "terraform-state"
      adr         = "adr-0003"
    },
    var.labels,
  )

  # CMEK ordering race (seen live in A1): bucket creation fails 403 unless
  # the GCS service account's key grant is IN FORCE first — depend on the
  # binding, not just the key.
  depends_on = [google_kms_crypto_key_iam_member.gcs_service_account]

  lifecycle {
    prevent_destroy = true
  }
}

# --- Access log bucket --------------------------------------------------------
# Receives GCS access/usage logs for the state bucket. CMEK with the SAME
# environment key (its name matches the *tfstate* convention, so
# require-cmek.rego demands it anyway). Logs are evidence: versioned,
# uniform access, no public access, not destroyable by terraform.
resource "google_storage_bucket" "state_logs" {
  # checkov:skip=CKV_GCP_62: this IS the log sink — the state bucket's
  # access logs land here (logging block above). GCS cannot deliver a
  # bucket's logs to itself, and Cloud Audit Logs (admin + data access,
  # configured below) already covers the forensic questions for this
  # bucket. Mirrors the documented-skip doctrine in modules/github-org.
  project       = var.project_id
  name          = "${var.bucket_name}-logs"
  location      = var.region
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.state.id
  }

  labels = merge(
    {
      environment = var.environment
      purpose     = "terraform-state-access-logs"
      adr         = "adr-0003"
    },
    var.labels,
  )

  # Same CMEK ordering race as the state bucket above.
  depends_on = [google_kms_crypto_key_iam_member.gcs_service_account]

  lifecycle {
    prevent_destroy = true
  }
}

# --- Dedicated state service account ------------------------------------------
# No human members, no basic roles (no-basic-iam-roles.rego). objectAdmin is
# the minimum that covers state read/write/list/lock; it is bucket-scoped.

resource "google_service_account" "state" {
  project      = var.project_id
  account_id   = "tfstate-${var.environment}"
  display_name = "Terraform state access (${var.environment}) — ADR-0003"
}

resource "google_storage_bucket_iam_member" "state_sa" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.state.email}"
}

resource "google_kms_crypto_key_iam_member" "state_sa" {
  crypto_key_id = google_kms_crypto_key.state.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.state.email}"
}

# --- CI impersonation via Workload Identity Federation ------------------------
# CI never holds SA JSON keys: the WIF principal (pinned repo+ref attribute
# condition, docs/workload-identity-federation.md) gets tokenCreator on the
# state SA and backend config impersonates it. Deferred until ci_principal
# is supplied (post-bootstrap step).

resource "google_service_account_iam_member" "ci_impersonation" {
  count = var.ci_principal != "" ? 1 : 0

  service_account_id = google_service_account.state.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = var.ci_principal
}

# --- Audit logging -------------------------------------------------------------
# GCS admin + data-access audit logs for the project (compliance log sink
# routing is a project concern; the state-compromise runbook depends on
# DATA_READ visibility to answer "who read the state?").

resource "google_project_iam_audit_config" "gcs_audit" {
  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
