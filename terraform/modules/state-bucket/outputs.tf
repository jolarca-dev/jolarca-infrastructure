# state-bucket outputs — consumed by the bootstrap runbook and the
# backend configs. No secret material is exported: these are identifiers
# and the custody record (who can touch the state).

output "bucket_name" {
  description = "State bucket name (belongs in backends/<env>.backend.hcl)."
  value       = google_storage_bucket.state.name
}

output "bucket_url" {
  description = "State bucket URL."
  value       = "gs://${google_storage_bucket.state.name}"
}

output "log_bucket_name" {
  description = "Access/usage log bucket for the state bucket (evidence, versioned)."
  value       = google_storage_bucket.state_logs.name
}

output "kms_key_id" {
  description = "CMEK key used for state encryption (record in security/key-custody.md)."
  value       = google_kms_crypto_key.state.id
}

output "kms_key_ring_id" {
  description = "Environment-scoped KMS keyring."
  value       = google_kms_key_ring.state.id
}

output "state_service_account_email" {
  description = "Dedicated state access SA — impersonate via WIF in CI; no human members."
  value       = google_service_account.state.email
}

output "gcs_encryption_principal" {
  description = "GCS service account holding CMEK encrypterDecrypter (custody record)."
  value       = "service-${data.google_project.current.number}@gs-project-accounts.com"
}
