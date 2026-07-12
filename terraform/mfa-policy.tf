resource "aws_iam_policy" "require_mfa" {
  name        = "require-mfa-${var.prefix}"
  description = "Denies most actions unless MFA is present on the session"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllExceptListedIfNoMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_user_policy_attachment" "vlad_admin_mfa" {
  user       = "vlad-admin"
  policy_arn = aws_iam_policy.require_mfa.arn
}
