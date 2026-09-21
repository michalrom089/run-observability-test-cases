# One stack per test case. The key is the project root in this repository.
locals {
  projects = {
    "simple" = {
      description = "The plan and the apply both succeed. Every run has a change to apply."
    }
    "single-error" = {
      description = "The plan succeeds. The apply fails with one error."
    }
    "multiple-errors" = {
      description = "The plan succeeds. The apply fails with two errors in parallel."
    }
  }
}

resource "spacelift_stack" "test_case" {
  for_each = local.projects

  name        = "${var.name_prefix}-${each.key}"
  description = each.value.description

  repository   = var.repository
  branch       = var.branch
  project_root = each.key

  # terraform_workflow_tool options: "TERRAFORM_FOSS", "OPEN_TOFU", "CUSTOM"
  terraform_workflow_tool = "OPEN_TOFU"
  terraform_version       = var.tofu_version

  space_id   = var.space_id
  autodeploy = var.autodeploy

  labels = ["run-observability", "test-case", each.key]
}
