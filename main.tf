###############################################################################
# Nimvault — OCI Service Account Setup
#
# This stack automatically creates everything Nimvault needs to connect
# to your OCI Object Storage. You don't need to know what OCIDs or PEM
# keys are — just select your Compartment and click Apply.
#
# After Apply completes:
#   1. Go to the "Outputs" tab below
#   2. Click the "nimvault_callback_url" link — it takes you back to
#      WordPress with everything pre-filled
#   3. Or copy the JSON and paste it in Nimvault Settings
###############################################################################

terraform {
  required_version = ">= 1.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

provider "oci" {
  region = var.region
}

# ─── Variables ────────────────────────────────────────────────

variable "tenancy_ocid" {
  description = "Your tenancy — auto-filled by OCI, don't change this"
  type        = string
}

variable "region" {
  description = "The region where your Object Storage bucket lives"
  type        = string
}

variable "compartment_ocid" {
  description = "Select the compartment that contains your Object Storage bucket"
  type        = string
}

variable "nimvault_site_url" {
  description = "Your WordPress site URL (e.g. https://myblog.com) — for the auto-return link"
  type        = string
  default     = ""
}

variable "service_user_name" {
  description = "Name for the Nimvault service user"
  type        = string
  default     = "nimvault-service"
}

variable "service_user_email" {
  description = "Email for the service user (required by OCI Identity Domains)"
  type        = string
  default     = "nimvault-service@nimvault.cloud"
}

variable "create_vault_secret" {
  description = "Store PEM key in OCI Vault (requires existing Vault)"
  type        = bool
  default     = false
}

variable "vault_id" {
  description = "OCI Vault OCID (required if create_vault_secret = true)"
  type        = string
  default     = ""
}

variable "vault_key_id" {
  description = "OCI Vault Master Encryption Key OCID (required if create_vault_secret = true)"
  type        = string
  default     = ""
}

# ─── Data Sources ─────────────────────────────────────────────

data "oci_identity_tenancy" "tenancy" {
  tenancy_id = var.tenancy_ocid
}

data "oci_identity_compartment" "target" {
  id = var.compartment_ocid
}

locals {
  # Root compartment uses "tenancy" syntax, non-root uses "compartment id <ocid>"
  is_root_compartment = var.compartment_ocid == var.tenancy_ocid
  policy_scope = local.is_root_compartment ? "tenancy" : "compartment id ${var.compartment_ocid}"
}

# ─── RSA Key Pair ─────────────────────────────────────────────

resource "tls_private_key" "nimvault" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# ─── IAM User (API Key only, no console login) ───────────────

resource "oci_identity_user" "nimvault" {
  compartment_id = var.tenancy_ocid
  name           = var.service_user_name
  description    = "Nimvault service account - Object Storage access only"
  email          = var.service_user_email

  freeform_tags = {
    "managed-by" = "nimvault-terraform-stack"
    "purpose"    = "object-storage-management"
  }
}

# Disable all capabilities except API Keys
resource "oci_identity_user_capabilities_management" "nimvault" {
  user_id = oci_identity_user.nimvault.id

  can_use_api_keys             = true
  can_use_auth_tokens          = false
  can_use_console_password     = false
  can_use_customer_secret_keys = false
  can_use_smtp_credentials     = false
}

# ─── API Key Registration ────────────────────────────────────

resource "oci_identity_api_key" "nimvault" {
  user_id   = oci_identity_user.nimvault.id
  key_value = tls_private_key.nimvault.public_key_pem
}

# ─── IAM Group ────────────────────────────────────────────────

resource "oci_identity_group" "nimvault" {
  compartment_id = var.tenancy_ocid
  name           = "NimvaultServiceUsers"
  description    = "Nimvault service accounts - minimum privilege for Object Storage"

  freeform_tags = {
    "managed-by" = "nimvault-terraform-stack"
  }
}

resource "oci_identity_user_group_membership" "nimvault" {
  group_id = oci_identity_group.nimvault.id
  user_id  = oci_identity_user.nimvault.id
}

# ─── IAM Policy (Minimum Privilege) ──────────────────────────
# Policy is created in the TARGET compartment (not tenancy root).
# This requires only compartment-level admin, not tenancy admin.

resource "oci_identity_policy" "nimvault_storage" {
  compartment_id = var.compartment_ocid
  name           = "nimvault-object-storage-policy"
  description    = "Nimvault Object Storage access"

  statements = [
    "Allow group NimvaultServiceUsers to manage objects in compartment id ${var.compartment_ocid}",
    "Allow group NimvaultServiceUsers to read buckets in compartment id ${var.compartment_ocid}",
    "Allow group NimvaultServiceUsers to manage preauthenticated-requests in compartment id ${var.compartment_ocid}",
    "Allow group NimvaultServiceUsers to read objectstorage-namespaces in tenancy",
  ]

  depends_on = [oci_identity_user_group_membership.nimvault]

  freeform_tags = {
    "managed-by" = "nimvault-terraform-stack"
  }
}

# ─── Optional: Store PEM in OCI Vault ─────────────────────────

resource "oci_vault_secret" "nimvault_pem" {
  count          = var.create_vault_secret ? 1 : 0
  compartment_id = var.compartment_ocid
  vault_id       = var.vault_id
  key_id         = var.vault_key_id
  secret_name    = "nimvault-service-pem-key"
  description    = "Nimvault service account PEM private key"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(tls_private_key.nimvault.private_key_pem)
  }

  freeform_tags = {
    "managed-by" = "nimvault-terraform-stack"
  }
}

# ─── Outputs ──────────────────────────────────────────────────
#
# After Apply, go to the "Outputs" tab.
# Easiest: click nimvault_callback_url to auto-return to WordPress.
# Or: download JSON and drop it in Nimvault Settings.

output "nimvault_setup_instructions" {
  value = <<-EOT
  Setup complete! Service account + policy created automatically.

  Return to WordPress:
     OPTION A (easiest): Click the "nimvault_callback_url" link below.
     OPTION B: Copy Outputs as JSON > paste in Nimvault Settings.
     OPTION C: Copy values manually into Nimvault Settings fields.
  EOT
  description = "How to finish setup"
}

output "nimvault_callback_url" {
  value       = var.nimvault_site_url != "" ? "${var.nimvault_site_url}/wp-admin/admin.php?page=nimvault-settings&nimvault_tf_callback=1&tf_tenancy=${var.tenancy_ocid}&tf_user=${oci_identity_user.nimvault.id}&tf_fingerprint=${oci_identity_api_key.nimvault.fingerprint}&tf_region=${var.region}" : "⚠️ Enter your WordPress URL in the stack variables to enable this link"
  description = "🔗 Click this link to auto-configure WordPress (enter nimvault_site_url above to enable)"
}

output "nimvault_tenancy_ocid" {
  value       = var.tenancy_ocid
  description = "Tenancy OCID — auto-detected from your OCI account"
}

output "nimvault_user_ocid" {
  value       = oci_identity_user.nimvault.id
  description = "Service user OCID — the dedicated account created for Nimvault"
}

output "nimvault_fingerprint" {
  value       = oci_identity_api_key.nimvault.fingerprint
  description = "API key fingerprint — identifies the RSA key pair"
}

output "nimvault_region" {
  value       = var.region
  description = "OCI region — where your Object Storage bucket is"
}

output "nimvault_private_key_pem" {
  value       = tls_private_key.nimvault.private_key_pem
  sensitive   = true
  description = "⚠️ Private key (shown ONCE) — needed only if using manual setup or JSON import"
}

output "nimvault_compartment" {
  value       = var.compartment_ocid
  description = "Compartment OCID"
}

output "nimvault_compartment_name" {
  value       = local.is_root_compartment ? "tenancy (root)" : coalesce(data.oci_identity_compartment.target.name, var.compartment_ocid)
  description = "Compartment name"
}

output "nimvault_vault_secret_ocid" {
  value       = var.create_vault_secret ? oci_vault_secret.nimvault_pem[0].id : "N/A (Vault not used)"
  description = "Vault Secret OCID (if Vault enabled)"
}
