# no-public-ips.rego — enforced by Conftest in security-scan.yml against
# `terraform show -json` plan output.
#
# Doctrine: the moat has no directly internet-addressable compute. Ingress
# exists only at the edge proxy (nginx on bare metal / GKE ingress);
# everything else is private. Public exposure of a workload is a
# trust-boundary violation (security/isolation-model.md).
package main

import rego.v1

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_compute_instance"
	not resource.change.after.access_config == null
	msg := sprintf("public IP not allowed: %s (%s) — route traffic through the edge proxy", [resource.address, resource.type])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_compute_address"
	resource.change.after.address_type == "EXTERNAL"
	msg := sprintf("external static address not allowed: %s", [resource.address])
}
