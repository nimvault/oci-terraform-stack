# Nimvault OCI Service Account Stack

Terraform stack that creates a dedicated OCI service account for
[Nimvault](https://nimvault.cloud) — the OCI Object Storage file
management platform for WordPress.

## What this creates

| Resource | Name | Purpose |
|----------|------|---------|
| **IAM User** | `nimvault-service` | API-only, no console login |
| **IAM Group** | `NimvaultServiceUsers` | Minimum privilege group |
| **IAM Policy** | `nimvault-object-storage-policy` | Object Storage manage/read/PAR only |
| **API Key** | RSA 2048 | Auto-generated key pair for authentication |

## How to use

### Option A: One-click from Nimvault (recommended)

1. In WordPress admin → **Nimvault → Settings → Terraform tab**
2. Click **"Connect to OCI (Resource Manager)"**
3. Nimvault shows a **public key** — copy it. Your site created the key pair and keeps the private key.
4. In the stack, select your **Compartment**, paste the key into **Nimvault public key**, and click **Apply**
5. Click the **callback URL** in Outputs to return to WordPress — the connection is complete

### Option B: Manual deployment

1. Go to [OCI Resource Manager — Create Stack](https://cloud.oracle.com/resourcemanager/stacks/create)
2. Source: **URL** → paste:
   ```
   https://github.com/nimvault/oci-terraform-stack/archive/refs/tags/v2.zip
   ```
3. Configure variables (Region, Compartment, Nimvault public key, WordPress URL)
4. **Create** → **Apply**

## After deployment

| Method | How |
|--------|-----|
| **Callback URL** (easiest) | Click `nimvault_callback_url` in Outputs → auto-fills WordPress |
| **JSON Import** (complete) | Copy Outputs as JSON → drag into Nimvault Settings |
| **Manual** | Copy each Output value into Nimvault Settings fields |

> 🔒 **v2:** this stack never creates or outputs a private key, so the private key is not in the Outputs or in the
> Terraform state. It is created by your WordPress site and never leaves it. (v1 — the `main` branch — still generates
> the key inside the stack for older Nimvault versions.)

## Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `region` | Yes | — | Region where your Object Storage bucket lives |
| `compartment_ocid` | Yes | — | Compartment containing your bucket |
| `nimvault_public_key_pem` | Yes | — | Public key shown in Nimvault Settings (not a secret) |
| `nimvault_site_url` | No | (empty) | Your WordPress URL — enables auto-return link |
| `service_user_name` | No | `nimvault-service` | IAM user name |
| `service_user_email` | No | `nimvault-service@nimvault.cloud` | Required by Identity Domains |

## Requirements

- OCI tenancy with Object Storage enabled
- Permission to create IAM users (tenancy admin or delegated)
- Works with both Legacy IAM and Identity Domains

## Cleanup

To remove all resources created by this stack:

1. OCI Console → Resource Manager → Stacks
2. Select the Nimvault stack → **Destroy**
3. Confirm → wait for completion
4. Optionally delete the Stack itself

## License

Apache 2.0
