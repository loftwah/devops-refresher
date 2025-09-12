data "aws_route53_zone" "this" {
  name         = var.hosted_zone_name
  private_zone = false
}

data "aws_iam_openid_connect_provider" "eks" {
  arn = var.oidc_provider_arn
}

# ACM certificate for EKS domain
resource "aws_acm_certificate" "eks" {
  domain_name       = var.eks_domain_fqdn
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.eks.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
  zone_id = data.aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "eks" {
  certificate_arn         = aws_acm_certificate.eks.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

locals {
  oidc_url_host = replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")
}

# IRSA role for AWS Load Balancer Controller
data "aws_iam_policy_document" "lbc_trust" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url_host}:sub"
      values   = ["system:serviceaccount:${var.lbc_namespace}:${var.lbc_service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lbc" {
  name               = "devops-refresher-staging-eks-lbc"
  assume_role_policy = data.aws_iam_policy_document.lbc_trust.json
}

# Recommended AWS policy for the Load Balancer Controller (2023-2024 baseline)
# Source reference: https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json
resource "aws_iam_policy" "lbc" {
  name   = "devops-refresher-staging-eks-lbc"
  policy = <<'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow","Action": ["iam:CreateServiceLinkedRole","ec2:DescribeAccountAttributes","ec2:DescribeAddresses","ec2:DescribeAvailabilityZones","ec2:DescribeInternetGateways","ec2:DescribeVpcs","ec2:DescribeVpcPeeringConnections","ec2:DescribeSubnets","ec2:DescribeSecurityGroups","ec2:DescribeInstances","ec2:DescribeNetworkInterfaces","ec2:DescribeTags","ec2:GetCoipPoolUsage","ec2:DescribeCoipPools","elasticloadbalancing:DescribeLoadBalancers","elasticloadbalancing:DescribeLoadBalancerAttributes","elasticloadbalancing:DescribeListeners","elasticloadbalancing:DescribeListenerCertificates","elasticloadbalancing:DescribeSSLPolicies","elasticloadbalancing:DescribeRules","elasticloadbalancing:DescribeTargetGroups","elasticloadbalancing:DescribeTargetGroupAttributes","elasticloadbalancing:DescribeTargetHealth","elasticloadbalancing:DescribeTags","elasticloadbalancing:AddTags","elasticloadbalancing:RemoveTags","elasticloadbalancing:AddListenerCertificates","elasticloadbalancing:RemoveListenerCertificates","elasticloadbalancing:ModifyLoadBalancerAttributes","elasticloadbalancing:SetIpAddressType","elasticloadbalancing:SetSecurityGroups","elasticloadbalancing:SetSubnets","elasticloadbalancing:DeleteLoadBalancer","elasticloadbalancing:CreateLoadBalancer","elasticloadbalancing:CreateTargetGroup","elasticloadbalancing:DeleteTargetGroup","elasticloadbalancing:ModifyTargetGroup","elasticloadbalancing:ModifyTargetGroupAttributes","elasticloadbalancing:RegisterTargets","elasticloadbalancing:DeregisterTargets","elasticloadbalancing:CreateListener","elasticloadbalancing:DeleteListener","elasticloadbalancing:ModifyListener","elasticloadbalancing:AddTags","elasticloadbalancing:RemoveTags"],"Resource": "*"},
    {"Effect": "Allow","Action": ["cognito-idp:DescribeUserPoolClient","acm:ListCertificates","acm:DescribeCertificate","iam:ListServerCertificates","iam:GetServerCertificate","shield:GetSubscriptionState","wafv2:GetWebACL","wafv2:GetWebACLForResource","wafv2:AssociateWebACL","wafv2:DisassociateWebACL","shield:DescribeProtection","shield:CreateProtection","shield:DeleteProtection"],"Resource": "*"},
    {"Effect": "Allow","Action": ["ec2:AuthorizeSecurityGroupIngress","ec2:RevokeSecurityGroupIngress"],"Resource": "*"},
    {"Effect": "Allow","Action": ["ec2:CreateSecurityGroup"],"Resource": "*"},
    {"Effect": "Allow","Action": ["ec2:CreateTags"],"Resource": "arn:aws:ec2:*:*:security-group/*","Condition": {"StringEquals": {"ec2:CreateAction": "CreateSecurityGroup"},"Null": {"aws:RequestTag/elbv2.k8s.aws/cluster": "false"}}},
    {"Effect": "Allow","Action": ["ec2:CreateTags","ec2:DeleteTags"],"Resource": "arn:aws:ec2:*:*:security-group/*","Condition": {"Null": {"aws:RequestTag/elbv2.k8s.aws/cluster": "true","aws:ResourceTag/elbv2.k8s.aws/cluster": "false"}}},
    {"Effect": "Allow","Action": ["ec2:AuthorizeSecurityGroupIngress","ec2:RevokeSecurityGroupIngress","ec2:DeleteSecurityGroup"],"Resource": "*","Condition": {"Null": {"aws:ResourceTag/elbv2.k8s.aws/cluster": "false"}}},
    {"Effect": "Allow","Action": ["elasticloadbalancing:CreateLoadBalancer","elasticloadbalancing:CreateTargetGroup"],"Resource": "*","Condition": {"Null": {"aws:RequestTag/elbv2.k8s.aws/cluster": "false"}}},
    {"Effect": "Allow","Action": ["elasticloadbalancing:AddTags","elasticloadbalancing:RemoveTags","elasticloadbalancing:DeleteLoadBalancer","elasticloadbalancing:ModifyLoadBalancerAttributes","elasticloadbalancing:SetIpAddressType","elasticloadbalancing:SetSecurityGroups","elasticloadbalancing:SetSubnets","elasticloadbalancing:DeleteTargetGroup","elasticloadbalancing:ModifyTargetGroup","elasticloadbalancing:ModifyTargetGroupAttributes"],"Resource": "*","Condition": {"Null": {"aws:ResourceTag/elbv2.k8s.aws/cluster": "false"}}},
    {"Effect": "Allow","Action": ["elasticloadbalancing:RegisterTargets","elasticloadbalancing:DeregisterTargets","elasticloadbalancing:CreateListener","elasticloadbalancing:DeleteListener","elasticloadbalancing:ModifyListener","elasticloadbalancing:AddListenerCertificates","elasticloadbalancing:RemoveListenerCertificates"],"Resource": "*"},
    {"Effect": "Allow","Action": ["iam:CreateServiceLinkedRole"],"Resource": "*","Condition": {"StringEquals": {"iam:AWSServiceName": ["elasticloadbalancing.amazonaws.com","ops.apigateway.amazonaws.com"]}}},
    {"Effect": "Allow","Action": ["ec2:DescribeAddresses","ec2:DescribeNetworkInterfaces","ec2:DescribeVpcs","ec2:DescribeVpcPeeringConnections","ec2:DescribeSubnets","ec2:DescribeSecurityGroups","ec2:DescribeInstances","ec2:DescribeTags","ec2:GetCoipPoolUsage","ec2:DescribeCoipPools"],"Resource": "*"}
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "lbc_attach" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

# IRSA role for ExternalDNS, limited to the hosted zone
data "aws_iam_policy_document" "externaldns_trust" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals { type = "Federated" identifiers = [var.oidc_provider_arn] }
    condition { test = "StringEquals" variable = "${local.oidc_url_host}:sub" values = ["system:serviceaccount:${var.externaldns_namespace}:${var.externaldns_service_account}"] }
    condition { test = "StringEquals" variable = "${local.oidc_url_host}:aud" values = ["sts.amazonaws.com"] }
  }
}

resource "aws_iam_role" "externaldns" {
  name               = "devops-refresher-staging-externaldns"
  assume_role_policy = data.aws_iam_policy_document.externaldns_trust.json
}

data "aws_iam_policy_document" "externaldns" {
  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = ["arn:aws:route53:::hostedzone/${data.aws_route53_zone.this.zone_id}"]
  }
  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:GetHostedZone"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "externaldns" {
  name   = "devops-refresher-staging-externaldns"
  policy = data.aws_iam_policy_document.externaldns.json
}

resource "aws_iam_role_policy_attachment" "externaldns_attach" {
  role       = aws_iam_role.externaldns.name
  policy_arn = aws_iam_policy.externaldns.arn
}

