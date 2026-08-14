# Staging tfvars — NON-SECRET values only.
# Anything credential-shaped belongs in Vaultwarden / the operator
# environment, never here. Reviewers: reject PRs that add secrets to this
# file (it is a CI audit target).

environment = "staging"
region      = "europe-west1"
