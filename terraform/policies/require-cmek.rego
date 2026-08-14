# require-cmek.rego — enforced by Conftest in security-scan.yml.
#
# Doctrine: state buckets and any storage holding org data are encrypted
# with customer-managed keys. CMEK gives us revocability: pulling the key
# renders leaked copies unreadable — the core mitigation in
# docs/runbooks/state-compromise.md. ISO 27001 A.8.24, GDPR Art. 32.
package main

import rego.v1

# State buckets (terraform/README.md: buckets follow the jolm-tfstate-*
# naming convention) must carry an encryption key reference.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_storage_bucket"
	name := object.get(resource.change.after, "name", "")
	contains(name, "tfstate")
	not resource.change.after.encryption
	msg := sprintf("state bucket %s requires CMEK encryption (encryption block missing)", [resource.address])
}

# GKE boot disks: default Google-managed keys are insufficient for
# workload-bearing nodes in the moat.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_cluster"
	not resource.change.after.database_encryption
	msg := sprintf("GKE cluster %s requires application-layer secrets encryption (database_encryption)", [resource.address])
}
