# ============================================================
# Landing Zone consumption (source of truth).
# This stack never creates VPCs, subnets, NAT, ECR repositories, KMS keys, ACM certificates,
# Route 53 zones, GitHub OIDC providers, GuardDuty detectors, Security Hub, flow logs or state buckets.
# ============================================================

variable "landing_zone_state_bucket" {
  description = "S3 bucket holding the Landing Zone Terraform state"
  type        = string
}

variable "landing_zone_state_key" {
  description = "S3 key of the Landing Zone Terraform state"
  type        = string
}

variable "landing_zone_state_region" {
  description = "Region of the Landing Zone state bucket"
  type        = string
}

variable "expected_landing_zone_contract_version" {
  description = "Landing Zone contract_schema_version this stack was written against"
  type        = string
  default     = "2"
}

variable "environment" {
  description = "dev, stage or prod"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be dev, stage or prod."
  }
}

variable "primary_region" {
  description = "Primary region (Cape Town)"
  type        = string
  default     = "af-south-1"

  validation {
    condition     = var.primary_region == "af-south-1"
    error_message = "Approved primary region is af-south-1."
  }
}

variable "dr_region" {
  description = "Disaster recovery region (Ireland). Also where services unavailable in af-south-1 are deployed."
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = var.dr_region == "eu-west-1"
    error_message = "Approved DR region is eu-west-1."
  }
}

data "terraform_remote_state" "landing_zone" {
  backend = "s3"

  config = {
    bucket  = var.landing_zone_state_bucket
    key     = var.landing_zone_state_key
    region  = var.landing_zone_state_region
    encrypt = true
  }
}

locals {
  lz = data.terraform_remote_state.landing_zone.outputs

  lz_primary = local.lz.af_south_1
  lz_dr      = local.lz.eu_west_1

  # Region this deployment targets (variables only, so the provider can use it)
  is_dr         = var.deployment_role == "dr"
  active_region = local.is_dr ? var.dr_region : var.primary_region
  net           = local.is_dr ? local.lz_dr : local.lz_primary

  vpc_id             = local.net.vpc_id
  vpc_cidr           = local.net.vpc_cidr_block
  azs                = local.net.azs
  public_subnet_ids  = local.net.public_subnet_ids
  private_subnet_ids = local.net.private_subnet_ids

  # DNS and TLS from the Landing Zone (the certificate and zone are never created here)
  route53_zone_id  = local.lz.route53_zone_id
  route53_domain   = local.lz.route53_domain_name
  acm_certificate  = local.is_dr ? var.dr_acm_certificate_arn : local.lz.acm_certificate_arn
  github_oidc_arn  = local.lz.github_oidc_provider_arn
  alerts_topic_arn = try(local.lz.monitoring_topic_arn, null)
  app_image_repo   = local.is_dr ? var.dr_image_repository : local.shared_ecr_urls["shared-applications"]

  key_strategy    = local.lz.key_strategy
  use_cmk         = local.key_strategy != "aws-managed"
  shared_kms_keys = local.lz.shared_kms_keys

  # Shared ECR repositories (the repository for application images is shared-applications)
  shared_ecr_urls = local.lz.ecr_repository_urls

  security_hub_enabled = try(local.lz.security_hub_enabled, false)

  name_prefix = "${var.workload_name}-${var.environment}"

  tags = {
    Project     = "aws-ecs-blue-green-deployment"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }

  kms_arn = {
    for purpose, domain in var.kms_key_domains :
    purpose => local.use_cmk ? try(local.shared_kms_keys[domain].arn, null) : null
  }
}

variable "workload_name" {
  description = "Workload name prefix"
  type        = string
  default     = "url-shortener"
}

variable "owner" {
  description = "Owning team (tag)"
  type        = string
}

variable "cost_center" {
  description = "Cost centre (tag)"
  type        = string
}

variable "kms_key_domains" {
  description = "Purpose => Landing Zone shared_kms_keys domain. Used only when the Landing Zone key_strategy is not aws-managed. 'dynamodb' and 'sqs' mapped to 'rds' are ASSUMPTIONS: the Landing Zone currently exports ai, analytics, backup, rds and s3 only."
  type        = map(string)
  default = {
    dynamodb = "rds"
    sqs      = "rds"
  }
}

variable "deployment_role" {
  description = "primary = af-south-1 (default). dr = eu-west-1 recovery deployment using the Landing Zone eu_west_1 network."
  type        = string
  default     = "primary"

  validation {
    condition     = contains(["primary", "dr"], var.deployment_role)
    error_message = "deployment_role must be primary or dr."
  }
}

variable "dr_acm_certificate_arn" {
  description = "ACM certificate in eu-west-1 for the DR load balancer. The Landing Zone exports only an af-south-1 and a us-east-1 certificate."
  type        = string
  default     = null
}

variable "dr_image_repository" {
  description = "ECR repository URL in eu-west-1 holding the application image (Landing Zone ECR replication to eu-west-1 is not exported)."
  type        = string
  default     = null
}

# ---- Guardrails: fail the plan when the Landing Zone does not fit ----
resource "terraform_data" "landing_zone_contract" {
  lifecycle {
    precondition {
      condition     = local.lz.contract_schema_version == var.expected_landing_zone_contract_version
      error_message = "Landing Zone contract_schema_version is '${local.lz.contract_schema_version}', expected '${var.expected_landing_zone_contract_version}'."
    }
    precondition {
      condition     = local.lz_primary.region == var.primary_region && local.lz_dr.region == var.dr_region
      error_message = "Landing Zone regions do not match primary_region/dr_region."
    }
    precondition {
      condition     = var.environment == "dev" || local.use_cmk
      error_message = "stage/prod require Customer Managed Keys, but the Landing Zone key_strategy is 'aws-managed'. This repo never creates keys: extend the Landing Zone export."
    }
    precondition {
      condition     = !local.use_cmk || alltrue([for p in keys(var.kms_key_domains) : local.kms_arn[p] != null])
      error_message = "key_strategy is CMK but shared_kms_keys lacks an arn for a mapped domain (see var.kms_key_domains)."
    }
    precondition {
      condition     = contains(keys(local.shared_ecr_urls), "shared-applications")
      error_message = "Landing Zone does not export the shared-applications ECR repository."
    }
    precondition {
      condition     = length(local.private_subnet_ids) >= 2 && length(local.public_subnet_ids) >= 2
      error_message = "The Landing Zone network must export at least two public and two private subnets (ALB needs two AZs)."
    }
    precondition {
      condition     = try(local.lz.route53_zone_id, null) != null && try(local.lz.route53_domain_name, null) != null
      error_message = "Landing Zone does not export route53_zone_id and route53_domain_name."
    }
    precondition {
      condition     = local.acm_certificate != null
      error_message = "No ACM certificate for this region. Primary uses the Landing Zone acm_certificate_arn; DR needs dr_acm_certificate_arn."
    }
    precondition {
      condition     = try(local.lz.github_oidc_provider_arn, null) != null
      error_message = "Landing Zone does not export github_oidc_provider_arn."
    }
    precondition {
      condition     = !var.enable_dynamodb_replication || !local.use_cmk || var.dr_dynamodb_kms_key_arn != null
      error_message = "DynamoDB replication with a Landing Zone CMK needs dr_dynamodb_kms_key_arn (a key in eu-west-1); the Landing Zone does not export one."
    }
    precondition {
      condition     = !local.is_dr || (var.dr_image_repository != null && var.dr_acm_certificate_arn != null)
      error_message = "deployment_role = dr requires dr_image_repository and dr_acm_certificate_arn."
    }
  }
}
