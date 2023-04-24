data "aws_canonical_user_id" "current_user" {}

data "aws_caller_identity" "current" {}

data "aws_acm_certificate" "ssl_certificate" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}
