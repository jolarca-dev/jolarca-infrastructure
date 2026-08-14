# no-basic-iam-roles.rego — enforced by Conftest in security-scan.yml.
#
# Doctrine: least privilege. Basic roles (owner/editor/viewer) grant
# unbounded scope across all services and are banned for service accounts
# and workload bindings. Use curated per-service roles via the iam module.
# SOC 2 CC6.1 / ISO 27001 A.5.15.
package main

import rego.v1

banned_roles := {"roles/owner", "roles/editor", "roles/viewer"}

deny contains msg if {
	some resource in input.resource_changes
	contains(resource.type, "google_")
	contains(resource.type, "iam")
	some binding in object.get(resource.change.after, "members", [])
	some role in banned_roles
	role in binding
	msg := sprintf("basic IAM role %s banned: %s", [role, resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	contains(resource.type, "google_")
	contains(resource.type, "iam")
	role := object.get(resource.change.after, "role", "")
	role in banned_roles
	msg := sprintf("basic IAM role %s banned: %s", [role, resource.address])
}
