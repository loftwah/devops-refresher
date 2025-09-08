data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "tf-state-${local.account_id}-${var.aws_region}"
}

