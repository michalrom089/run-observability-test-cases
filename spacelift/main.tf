# One stack per entry. The key is the stack name suffix, not the project root.
# Two stacks can share a project root and differ only in how many runs they hold.
#
# runs            is how many runs the stack starts with.
# slow_after      is how many of those runs are fast. The rest get a slow run
#                 environment. null means every run is fast.
#
# An entry can also set these. stack_defaults holds the value an entry omits.
#
# random_versions gives each run its own RANDOM_VERSION. Set one per run.
# before_init,
# after_init,
# before_plan     are hooks the stack runs in that phase.
# private_worker  puts the stack on var.worker_pool_id. The stack exists only
#                 when that variable is set.
locals {
  stack_entries = {
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
    "no-changes" = {
      project_root = "no-changes"
      description  = "The first run creates the resources. Every run after it changes nothing."
      runs         = 3
      slow_after   = null
    }
    "slow-runs" = {
      project_root = "slow-runs"
      description  = "The apply succeeds. The first three runs are fast. The rest are slow."
      runs         = 6
      slow_after   = 3
    }
    "provider-version-change" = {
      project_root    = "provider-version-change"
      description     = "Every run pins hashicorp/random at a different version. Every run after the first changes the version."
      runs            = 3
      random_versions = ["3.6.0", "3.6.3", "3.7.1"]
      before_init     = ["sh pin-random.sh"]
    }
    "provider-version-conflict-one-state" = {
      project_root = "provider-version-conflict"
      description  = "Initializing resolves hashicorp/random at two versions."
      runs         = 1
      after_init   = ["tofu -chdir=pinned init -input=false"]
    }
    "provider-version-conflict-two-states" = {
      project_root = "provider-version-conflict"
      description  = "Initializing and planning resolve hashicorp/random at different versions."
      runs         = 1
      before_plan  = ["tofu -chdir=pinned init -input=false"]
    }
    "slow-provider-install" = {
      project_root = "slow-provider-install"
      description  = "Init installs hashicorp/aws ten times without a provider cache, on a public worker."
      runs         = 1
      after_init   = ["sh reinstall-providers.sh"]
    }
    "slow-provider-install-private" = {
      project_root   = "slow-provider-install"
      description    = "Init installs hashicorp/aws ten times without a provider cache, on a private worker."
      runs           = 1
      after_init     = ["sh reinstall-providers.sh"]
      private_worker = true
    }
  }

  stack_defaults = {
    slow_after      = null
    random_versions = null
    before_init     = null
    after_init      = null
    before_plan     = null
    private_worker  = false
  }

  stacks = {
    for key, entry in local.stack_entries : key => merge(local.stack_defaults, entry)
    if !try(entry.private_worker, false) || var.worker_pool_id != null
  }

  # One entry per run. The key is unique, the value names the stack to run and
  # the RANDOM_VERSION the run pins, if any. The fast runs come first. The slow
  # runs follow, and they depend on the fast ones, so Spacelift queues them in
  # that order.
  fast_runs = merge([
    for key, stack in local.stacks : {
      for index in range(coalesce(stack.slow_after, stack.runs)) : "${key}-${index}" => {
        stack          = key
        random_version = stack.random_versions == null ? null : stack.random_versions[index]
      }
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

  before_init = each.value.before_init
  after_init  = each.value.after_init
  before_plan = each.value.before_plan

  space_id       = spacelift_space.test_cases.id
  worker_pool_id = each.value.private_worker ? var.worker_pool_id : null
  autodeploy     = var.autodeploy

  labels = ["run-observability", "test-case", each.value.project_root]
}

# The fast runs. A stack with runs = 0 gets none, which is what the `-no-runs`
# cases test. The runs fire once, at create.
resource "spacelift_run" "fast" {
  for_each = var.trigger_runs ? local.fast_runs : {}

  stack_id = spacelift_stack.test_case[each.value.stack].id

  # pin-random.sh reads RANDOM_VERSION. Only provider-version-change sets it.
  dynamic "runtime_config" {
    for_each = each.value.random_version == null ? [] : [each.value.random_version]

    content {
      environment {
        key   = "RANDOM_VERSION"
        value = runtime_config.value
      }
    }
  }
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
