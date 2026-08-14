# Staging environment outputs.
# Outputs are the only sanctioned channel for CI to surface resource facts;
# they must never contain secret material (SOC 2 CC6.6).

output "note" {
  description = "Placeholder until the GCP staging workstream lands."
  value       = "staging environment scaffold — no managed resources yet"
}
