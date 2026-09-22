# One stack per entry. The key is the stack name suffix, not the project root.
# Two stacks can share a project root and differ only in how many runs they hold.
#
# runs       is how many runs the stack starts with.
# slow_after is how many of those runs are fast. The rest get a slow run
#            environment. null means every run is fast.
locals {
  stacks = {
    "simple" = {
      project_root = "simple"
      description  = "The plan and the apply both succeed. Every run has a change to apply."
      runs         = 3
      slow_after   = null
    }
    "single-error" = {
      project_root = "single-error"
      description  = "The plan succeeds. The apply fails with one error."
      runs         = 3
      slow_after   = null
    }
    "multiple-errors" = {
      project_root = "multiple-errors"
      description  = "The plan succeeds. The apply fails with two errors in parallel."
      runs         = 3
      slow_after   = null
    }
    "simple-no-runs" = {
      project_root = "simple"
      description  = "The plan and the apply both succeed. The stack holds no runs."
      runs         = 0
      slow_after   = null
    }
    "single-error-no-runs" = {
      project_root = "single-error"
      description  = "The plan succeeds. The apply fails with one error. The stack holds no runs."
      runs         = 0
      slow_after   = null
    }
    "slow-runs" = {
      project_root = "slow-runs"
      description  = "The apply succeeds. The first three runs are fast. The rest are slow."
      runs         = 6
      slow_after   = 3
    }
  }

  # One entry per run. The key is unique, the value names the stack to run.
  # The fast runs come first. The slow runs follow, and they depend on the fast
  # ones, so Spacelift queues them in that order.
  fast_runs = merge([
    for key, stack in local.stacks : {
      for index in range(coalesce(stack.slow_after, stack.runs)) : "${key}-${index}" => key
    }
  ]...)

  slow_runs = merge([
    for key, stack in local.stacks : {
      for index in range(coalesce(stack.slow_after, stack.runs), stack.runs) : "${key}-${index}" => key
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

# The fast runs. A stack with runs = 0 gets none, which is what the `-no-runs`
# cases test. The runs fire once, at create.
resource "spacelift_run" "fast" {
  for_each = var.trigger_runs ? local.fast_runs : {}

  stack_id = spacelift_stack.test_case[each.value].id
}

# The slow runs. `sleep_seconds` makes the apply take its time, so a run
# duration alert has something to catch. They wait for the fast runs, so the
# slow ones are the later runs on the stack.
resource "spacelift_run" "slow" {
  for_each = var.trigger_runs ? local.slow_runs : {}

  stack_id = spacelift_stack.test_case[each.value].id

  runtime_config {
    environment {
      key   = "TF_VAR_sleep_seconds"
      value = tostring(var.slow_seconds)
    }
  }

  depends_on = [spacelift_run.fast]
}
