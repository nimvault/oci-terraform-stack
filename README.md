# Nimvault OCI Service Account Stack

Terraform stack that creates a dedicated OCI service account for
[Nimvault](https://nimvault.cloud) — the OCI Object Storage file
management platform for WordPress.

## What this creates

- **IAM User**: `nimvault-service` (API-only, no console login)
- **IAM Group**: `NimvaultServiceUsers`
- **IAM Policy**: Minimum privilege Object Storage access
- **API Key**: RSA 2048 key pair for authentication
- **(Optional)** PEM key stored in OCI Vault

## How to use

### Option A: One-click from Nimvault
In your WordPress admin → Nimvault → Settings → Terraform tab,
click "Open OCI Resource Manager". Everything is pre-configured.

### Option B: Manual deployment
1. Go to [OCI Resource Manager](https://cloud.oracle.com/resourcemanager/stacks/create)
2. Source: URL → paste this: 
   `https://github.com/nimvault/oci-terraform-stack/archive/refs/heads/main.zip`
3. Configure variables (Region, Compartment, WordPress URL)
4. Apply

## After deployment
- Click the `nimvault_callback_url` in Outputs to auto-configure WordPress
- Or download Output JSON and import it in Nimvault Settings

## Requirements
- OCI tenancy with Object Storage enabled
- Permission to create IAM users (tenancy admin or delegated)

## License
Apache 2.0
