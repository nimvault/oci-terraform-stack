###############################################################################
# Nimvault — OCI Service Account Setup
#
# This stack automatically creates everything Nimvault needs to connect
# to your OCI Object Storage. Select your Compartment, paste the public key
# that Nimvault shows you, and click Apply.
#
# v2 (TF-STACK-PRIVATE-KEY-PLAINTEXT-01): the private key is created by your
# WordPress site and never leaves it. This stack only receives the PUBLIC key,
# so no private key appears in the outputs or in the Terraform state.
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
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
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

variable "nimvault_public_key_pem" {
  description = "The public key shown in Nimvault Settings (PEM, starts with -----BEGIN PUBLIC KEY-----)"
  type        = string
}

# ─── Data Sources ─────────────────────────────────────────────

data "oci_identity_tenancy" "tenancy" {
  tenancy_id = var.tenancy_ocid
}

data "oci_identity_compartment" "target" {
  id = var.compartment_ocid
}

locals {
  is_root_compartment = var.compartment_ocid == var.tenancy_ocid
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
  key_value = trimspace(var.nimvault_public_key_pem)
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

# OCI IAM has a propagation delay after group creation.
resource "time_sleep" "wait_for_iam_group" {
  depends_on      = [oci_identity_group.nimvault]
  create_duration = "30s"
}

# ─── IAM Policy (Minimum Privilege) ──────────────────────────
# Policy attached at tenancy; scope limited to target compartment.
# PAR permissions are part of 'manage buckets' (not a separate resource-type).

resource "oci_identity_policy" "nimvault_storage" {
  compartment_id = var.tenancy_ocid
  name           = "nimvault-object-storage-policy"
  description    = "Nimvault Object Storage access"

  statements = [
    "Allow group id ${oci_identity_group.nimvault.id} to manage objects in compartment id ${var.compartment_ocid}",
    "Allow group id ${oci_identity_group.nimvault.id} to manage buckets in compartment id ${var.compartment_ocid}",
  ]

  depends_on = [time_sleep.wait_for_iam_group]

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
     No private key is shown here — your site already holds it.
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

output "nimvault_compartment" {
  value       = var.compartment_ocid
  description = "Compartment OCID"
}

output "nimvault_compartment_name" {
  value       = local.is_root_compartment ? "tenancy (root)" : coalesce(data.oci_identity_compartment.target.name, var.compartment_ocid)
  description = "Compartment name"
}
