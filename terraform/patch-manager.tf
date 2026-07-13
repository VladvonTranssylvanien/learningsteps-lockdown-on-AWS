resource "aws_ssm_patch_baseline" "ubuntu" {
  name             = "patch-baseline-${var.prefix}"
  operating_system = "UBUNTU"

  approval_rule {
    approve_after_days = 3
    compliance_level   = "CRITICAL"
    patch_filter {
      key    = "PRIORITY"
      values = ["Required", "Important"]
    }
  }
  tags = local.common_tags
}

resource "aws_ssm_patch_group" "app" {
  baseline_id = aws_ssm_patch_baseline.ubuntu.id
  patch_group = "learningsteps-${var.prefix}"
}

resource "aws_ssm_maintenance_window" "patching" {
  name     = "patch-window-${var.prefix}"
  schedule = "cron(0 4 ? * SUN *)"
  duration = 2
  cutoff   = 1
  tags     = local.common_tags
}

resource "aws_ssm_maintenance_window_target" "app" {
  window_id     = aws_ssm_maintenance_window.patching.id
  resource_type = "INSTANCE"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.vm.id]
  }
}

resource "aws_iam_role" "ssm_patch" {
  name = "ssm-patch-role-${var.prefix}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ssm.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_patch" {
  role       = aws_iam_role.ssm_patch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}

resource "aws_ssm_association" "inventory" {
  name                = "AWS-GatherSoftwareInventory"
  association_name    = "inventory-${var.prefix}"
  schedule_expression = "rate(1 day)"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.vm.id]
  }
}

resource "aws_ssm_maintenance_window_task" "patch" {
  window_id        = aws_ssm_maintenance_window.patching.id
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-RunPatchBaseline"
  priority         = 1
  service_role_arn = aws_iam_role.ssm_patch.arn
  max_concurrency  = "1"
  max_errors       = "1"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.app.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      parameter {
        name   = "Operation"
        values = ["Install"]
      }
    }
  }
}
