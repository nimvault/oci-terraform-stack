# Nimvault OCI Service Account Stack

Terraform stack that creates a dedicated OCI service account for
[Nimvault](https://nimvault.cloud) — the OCI Object Storage file
management platform for WordPress.

## What this creates

| Resource | Name | Purpose |
|----------|------|---------|
| **IAM User** | `nimvault-service` | API-only, no console login |
| **IAM Group** | `NimvaultServiceUsers` | Group for the Nimvault user |
| **IAM Policy** | `nimvault-object-storage-policy` | Manage buckets and objects in the compartment you choose |
| **API Key** | RSA 2048 | Registers the public key your site created (the stack never holds a private key) |

Creates a new OCI user only for Nimvault. It works only with buckets and objects in the compartment you choose.
You don't need to enter an admin account key.

## How to use

### Option A: Start from Nimvault

1. In WordPress admin → **Nimvault → Settings → Storage**, open the OCI credentials and choose the stack option
2. Follow the **"Create the stack in OCI"** link
3. Nimvault shows a **public key** — copy it. Your site created the key pair and keeps the private key.
4. In the stack, select your **Compartment**, paste the key into **Nimvault public key**, and click **Apply**
5. When the stack finishes, open the stack in the OCI Console, choose **View state › Copy**, and paste it into Nimvault

If the OCI Console opens in another region and shows an error, switch to your home region at the top of the console and continue.

### Option B: Manual deployment

1. Go to [OCI Resource Manager — Create Stack](https://cloud.oracle.com/resourcemanager/stacks/create)
2. Source: **URL** → paste:
   ```
   https://github.com/nimvault/oci-terraform-stack/archive/refs/tags/v2.2.zip
   ```
3. Configure variables (Region, Compartment, Nimvault public key, WordPress URL)
4. **Create** → **Apply**

## After deployment

| Method | How |
|--------|-----|
| **Paste the result** | Open the stack in the OCI Console → **View state › Copy** → paste into Nimvault Settings |
| **Manual** | Copy each Output value into Nimvault Settings fields |

> 🔒 **v2:** this stack never creates or outputs a private key, so the private key is not in the Outputs or in the
> Terraform state. It is created by your WordPress site and never leaves it. (Versions before v2 generated
> the key inside the stack; they are no longer offered.)

If Apply fails, see the reason in the stack's job log in the OCI Console. To try again, destroy that stack first.

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
