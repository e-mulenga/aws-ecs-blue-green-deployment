# URL mapping table. dev: AWS-owned/managed encryption. stage/prod: Landing Zone CMK (kms_key_arn).
resource "aws_dynamodb_table" "this" {
  name                        = var.name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "id"
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled     = var.kms_key_arn != null
    kms_key_arn = var.kms_key_arn
  }

  stream_enabled   = var.replica_region != null
  stream_view_type = var.replica_region != null ? "NEW_AND_OLD_IMAGES" : null

  dynamic "replica" {
    for_each = var.replica_region != null ? [var.replica_region] : []
    content {
      region_name = replica.value
      kms_key_arn = var.replica_kms_key_arn
    }
  }
}
