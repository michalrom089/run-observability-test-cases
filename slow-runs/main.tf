terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# The run environment sets this. A run that leaves it alone is a fast run.
variable "sleep_seconds" {
  type        = number
  description = "Seconds the slow resources and hooks share between them."
  default     = 0
}

# Steps that take the same time in every run. They run in parallel, so the
# list of slowest resources holds more than 5 entries in every run.
locals {
  steady_steps = {
    fetch   = 1
    compile = 3
    package = 2
    verify  = 2
    notify  = 1
  }

  # The two steps that get slow. A slow run gives migrate 20% and deploy 60% of
  # var.sleep_seconds. The hooks take the other 20%.
  migrate_seconds = 1 + floor(var.sleep_seconds * 20 / 100)
  deploy_seconds  = 2 + floor(var.sleep_seconds * 60 / 100)
}

# The timestamp forces replacement on every apply, so every run has work to do.
resource "terraform_data" "trigger" {
  input = timestamp()
}

# triggers_replace, not input. An input change updates the resource in place
# and a provisioner only runs at create, so the sleep would never repeat.
resource "terraform_data" "step" {
  for_each = local.steady_steps

  triggers_replace = terraform_data.trigger.output

  provisioner "local-exec" {
    command = "echo 'step ${each.key}: sleeping ${each.value} seconds' && sleep ${each.value}"
  }
}

# deploy waits for migrate, so the two slow sleeps add up.
resource "terraform_data" "migrate" {
  triggers_replace = terraform_data.trigger.output

  provisioner "local-exec" {
    command = "echo 'migrate: sleeping ${local.migrate_seconds} seconds' && sleep ${local.migrate_seconds}"
  }
}

resource "terraform_data" "deploy" {
  triggers_replace = terraform_data.migrate.id

  provisioner "local-exec" {
    command = "echo 'deploy: sleeping ${local.deploy_seconds} seconds' && sleep ${local.deploy_seconds}"
  }
}

resource "random_id" "output" {
  byte_length = 7

  keepers = {
    trigger = terraform_data.trigger.id
  }
}

output "random_id" {
  value       = random_id.output.hex
  description = "Random ID that changes on every apply."
}

output "sleep_seconds" {
  value       = var.sleep_seconds
  description = "Seconds the slow resources and hooks shared."
}

output "timestamp" {
  value       = terraform_data.trigger.output
  description = "Timestamp of the last apply."
}
