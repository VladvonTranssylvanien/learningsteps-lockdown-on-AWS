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
          "iam:ChangePassword",
          "iam:CreateVirtualMFADevice",
          "iam:DeactivateMFADevice",
          "iam:DeleteVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetAccountSummary",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetCallerIdentity",
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

# Attached at the group level (not per-user) so any admin added later
# inherits the MFA requirement automatically instead of being missed.
resource "aws_iam_group" "admins" {
  name = "admins-${var.prefix}"
}

resource "aws_iam_group_policy_attachment" "admins_require_mfa" {
  group      = aws_iam_group.admins.name
  policy_arn = aws_iam_policy.require_mfa.arn
}

resource "aws_iam_group_membership" "admins" {
  name  = "admins-membership-${var.prefix}"
  group = aws_iam_group.admins.name
  users = ["vlad-admin"]
}
