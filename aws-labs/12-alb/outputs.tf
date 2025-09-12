output "alb_arn" { value = aws_lb.app.arn }
output "alb_dns_name" { value = aws_lb.app.dns_name }
output "tg_arn" { value = aws_lb_target_group.app.arn }
output "listener_http_arn" { value = aws_lb_listener.http.arn }
output "listener_https_arn" { value = aws_lb_listener.https.arn }
output "certificate_arn" { value = aws_acm_certificate.this.arn }
output "record_fqdn" { value = aws_route53_record.app_alias.fqdn }
