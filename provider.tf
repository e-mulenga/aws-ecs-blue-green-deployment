terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {} # bucket/region/lockfile from environments/<env>/backend.tf; key from scripts/tf.sh
}

# Active region: af-south-1 for the primary deployment, eu-west-1 when deployment_role = "dr".
provider "aws" {
  region = local.active_region

  default_tags {
    tags = local.tags
  }
}

# Ireland (DR region): home of any service that is not available in af-south-1.
# The 2026-11-03 availability check found none (docs/regional-availability.md), so no resource
# uses this alias yet.
provider "aws" {
  alias  = "ireland"
  region = var.dr_region

  default_tags {
    tags = local.tags
  }
}
