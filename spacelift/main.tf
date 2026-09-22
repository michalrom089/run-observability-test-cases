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

# One space that holds every test case stack.
resource "spacelift_space" "test_cases" {
  name             = var.name_prefix
  parent_space_id  = var.parent_space_id
  description      = "Stacks that produce known run outcomes."
  inherit_entities = true

  labels = ["run-observability"]
}

resource "spacelift_stack" "test_case" {
  for_each = local.projects

  name        = "${var.name_prefix}-${each.key}"
  description = each.value.description

  repository   = var.repository
  branch       = var.branch
  project_root = each.key

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

  labels = ["run-observability", "test-case", each.key]
}
