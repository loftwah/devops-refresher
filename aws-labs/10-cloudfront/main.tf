locals {
  zone_name = var.hosted_zone_name
}

data "aws_route53_zone" "by_name" {
  count        = var.hosted_zone_id == "" ? 1 : 0
  name         = local.zone_name
  private_zone = false
}

data "aws_route53_zone" "by_id" {
  count   = var.hosted_zone_id != "" ? 1 : 0
  zone_id = var.hosted_zone_id
}

locals {
  zone_id = var.hosted_zone_id != "" ? var.hosted_zone_id : data.aws_route53_zone.by_name[0].zone_id
}

resource "aws_acm_certificate" "ecs" {
  provider          = aws.us_east_1
  domain_name       = var.ecs_domain
  validation_method = "DNS"
  tags              = merge(var.tags, { Name = "cf-cert-ecs" })
}

resource "aws_acm_certificate" "eks" {
  provider          = aws.us_east_1
  domain_name       = var.eks_domain
  validation_method = "DNS"
  tags              = merge(var.tags, { Name = "cf-cert-eks" })
}

resource "aws_route53_record" "ecs_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ecs.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_route53_record" "eks_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.eks.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "ecs" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.ecs.arn
  validation_record_fqdns = [for r in aws_route53_record.ecs_cert_validation : r.fqdn]
}

resource "aws_acm_certificate_validation" "eks" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.eks.arn
  validation_record_fqdns = [for r in aws_route53_record.eks_cert_validation : r.fqdn]
}

locals {
  api_cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  origin_request_policy_all_viewer = "216adef6-5c7f-47e4-b989-5492eafa07d3"
}

resource "aws_cloudfront_distribution" "ecs" {
  enabled             = true
  aliases             = [var.ecs_domain]

  origin {
    domain_name = var.ecs_alb_dns_name
    origin_id   = "ecs-alb-origin"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id         = "ecs-alb-origin"
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = local.api_cache_policy_id
    origin_request_policy_id = local.origin_request_policy_all_viewer
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
  }

  restrictions { geo_restriction { restriction_type = "none" } }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.ecs.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = merge(var.tags, { Name = "cf-ecs" })
}

resource "aws_cloudfront_distribution" "eks" {
  enabled             = true
  aliases             = [var.eks_domain]

  origin {
    domain_name = var.eks_alb_dns_name
    origin_id   = "eks-alb-origin"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id         = "eks-alb-origin"
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = local.api_cache_policy_id
    origin_request_policy_id = local.origin_request_policy_all_viewer
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
  }

  restrictions { geo_restriction { restriction_type = "none" } }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.eks.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = merge(var.tags, { Name = "cf-eks" })
}

resource "aws_route53_record" "ecs_alias" {
  zone_id = local.zone_id
  name    = var.ecs_domain
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.ecs.domain_name
    zone_id                = aws_cloudfront_distribution.ecs.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "eks_alias" {
  zone_id = local.zone_id
  name    = var.eks_domain
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.eks.domain_name
    zone_id                = aws_cloudfront_distribution.eks.hosted_zone_id
    evaluate_target_health = false
  }
}

