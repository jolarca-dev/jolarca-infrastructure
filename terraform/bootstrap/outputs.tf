# Bootstrap outputs — record these in security/key-custody.md and the
# change record (SOC 2 CC8.1) after each bootstrap apply.

output "bucket_name" {
  description = "State bucket created for this environment."
  value       = module.state_bucket.bucket_name
}

output "kms_key_id" {
  description = "CMEK key ID (custody record)."
  value       = module.state_bucket.kms_key_id
}

output "state_service_account_email" {
  description = "State access SA (custody record)."
  value       = module.state_bucket.state_service_account_email
}

output "gcs_encryption_principal" {
  description = "GCS service account with CMEK encrypterDecrypter (custody record)."
  value       = module.state_bucket.gcs_encryption_principal
}
