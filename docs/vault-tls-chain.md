# Vault TLS Chain — Internal CA Documentation

## Chain of Trust

```
Root CA (self-signed, offline)
  └── Intermediate CA (Vault PKI)
        └── Leaf certificates (Vault, services)
```

## Bootstrap Order

When standing up Vault for the first time, the TLS certificate
chicken-and-egg problem requires this specific order:

### Step 1: Bootstrap Internal CA

If Vault PKI is not yet available, use `step-ca` or OpenSSL to create
a minimal internal CA:

```bash
# Generate root CA (offline, sealed)
openssl req -x509 -new -nodes -keyout ca-key.pem -sha256 -days 3650 \
  -out ca-cert.pem -subj "/CN=Jolarca Internal CA"

# The root CA key is sealed offline per key-custody.md
# The root CA cert is distributed to all VMs at /etc/ssl/certs/jolarca-ca.pem
```

### Step 2: Issue Vault Certificate

```bash
# Generate Vault server certificate signed by internal CA
openssl req -new -key vault-key.pem -out vault.csr \
  -subj "/CN=vault.service.consul"

openssl x509 -req -in vault.csr -CA ca-cert.pem -CAkey ca-key.pem \
  -CAcreateserial -out vault-cert.pem -days 365 -sha256 \
  -extfile <(printf "subjectAltName=DNS:vault.service.consul,DNS:localhost,IP:10.10.1.4")
```

### Step 3: Vault Up

Start Vault with the issued certificate. Once Vault is running and
unsealed, enable the PKI secrets engine:

```bash
vault secrets enable pki
vault write pki/root/generate/internal \
  common_name="Jolarca Internal CA" \
  ttl=87600h
```

From this point forward, Vault PKI issues all internal service
certificates. The bootstrap CA from Step 1 is only used for Vault's
own initial certificate.

### Step 4: Distribute CA Cert

The internal CA certificate must be present on all VMs:

```
/etc/ssl/certs/jolarca-ca.pem
```

The hardening role (00-hardening.yml) distributes this file.

## Certificate Inventory

| Service | SAN | Issuer | TTL | Renewal |
|---------|-----|--------|-----|---------|
| Vault | vault.service.consul, 10.10.1.4 | Bootstrap CA | 1 year | Manual |
| PostgreSQL | db.service.consul, 10.10.1.3 | Vault PKI | 90 days | Auto |
| MinIO | minio.service.consul, 10.10.1.5 | Vault PKI | 90 days | Auto |
| nginx edge | marketplace.jolarca.org | Let's Encrypt | 90 days | dehydrated |

## Revocation

If a certificate is compromised:

```bash
# Revoke via Vault PKI
vault write pki/revoke serial_number="<serial>"

# Distribute updated CRL
# All services check CRL on connection
```

## Document References

- `security/key-custody.md` — CA key custody procedure
- `security/network-policy.md` — TLS enforcement rules
- `ansible/roles/vault/` — Vault installation and TLS config
- `ansible/playbooks/30-vault.yml` — Vault deployment playbook
