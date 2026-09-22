# One stack per entry. The key is the stack name suffix, not the project root.
# Two stacks can share a project root and differ only in how many runs they hold.
locals {
  stacks = {
    "simple" = {
      project_root = "simple"
      description  = "The plan and the apply both succeed. Every run has a change to apply."
      runs         = 3
    }
    "single-error" = {
      project_root = "single-error"
      description  = "The plan succeeds. The apply fails with one error."
      runs         = 3
    }
    "multiple-errors" = {
      project_root = "multiple-errors"
      description  = "The plan succeeds. The apply fails with two errors in parallel."
      runs         = 3
    }
    "simple-no-runs" = {
      project_root = "simple"
      description  = "The plan and the apply both succeed. The stack holds no runs."
      runs         = 0
    }
    "single-error-no-runs" = {
      project_root = "single-error"
      description  = "The plan succeeds. The apply fails with one error. The stack holds no runs."
      runs         = 0
    }
  }

  # One entry per run. The key is unique, the value names the stack to run.
  runs = merge([
    for key, stack in local.stacks : {
      for index in range(stack.runs) : "${key}-${index}" => key
    }
  ]...)
}

# One space that holds every test case stack.
resource "spacelift_space" "test_cases" {
  name             = var.repository
  parent_space_id  = var.parent_space_id
  description      = "Stacks that produce known run outcomes."
  inherit_entities = true

  labels = ["run-observability"]
}

resource "spacelift_stack" "test_case" {
  for_each = local.stacks

  name        = "${var.name_prefix}-${each.key}"
  description = each.value.description

  repository   = var.repository
  branch       = var.branch
  project_root = each.value.project_root

  # The raw Git vendor reads a public repository over HTTPS. No VCS integration.
  raw_git {
    namespace = var.git_namespace
    url       = var.git_url
  }

  # A native OpenTofu stack. The block replaces terraform_workflow_tool = "OPEN_TOFU".
  opentofu {
    version = var.tofu_version
  }

  space_id   = spacelift_space.test_cases.id
  autodeploy = var.autodeploy

  labels = ["run-observability", "test-case", each.value.project_root]
}

# The runs each stack holds. A stack with runs = 0 gets none, which is what the
# `-no-runs` cases test. The runs fire once, at create.
resource "spacelift_run" "test_case" {
  for_each = var.trigger_runs ? local.runs : {}

  stack_id = spacelift_stack.test_case[each.value].id
}
