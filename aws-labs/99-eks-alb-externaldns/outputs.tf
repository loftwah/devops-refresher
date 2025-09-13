output "zone_id" { value = data.aws_route53_zone.this.zone_id }
output "certificate_arn" { value = aws_acm_certificate_validation.eks.certificate_arn }
output "lbc_role_arn" { value = aws_iam_role.lbc.arn }
output "externaldns_role_arn" { value = aws_iam_role.externaldns.arn }

