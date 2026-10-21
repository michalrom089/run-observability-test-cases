terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# The stack applies with -parallelism=1, so the resources run one after another.
# The phase lasts about 150 seconds and no resource takes more than 8 of them.
locals {
  slowest_seconds = 8

  # Four resources just behind the slowest one, close to each other.
  near_steps = {
    grant-a = 5
    grant-b = 5
    grant-c = 5
    grant-d = 5
  }

  # Many short resources. They make the phase long, not any one resource.
  filler_count   = 40
  filler_seconds = 3
}

# The timestamp forces replacement on every apply, so every run has work to do.
resource "terraform_data" "trigger" {
  input = timestamp()
}

# triggers_replace, not input. An input change updates the resource in place
# and a provisioner only runs at create, so the sleep would never repeat.
resource "terraform_data" "slowest" {
  triggers_replace = terraform_data.trigger.output

  provisioner "local-exec" {
    command = "echo 'slowest: sleeping ${local.slowest_seconds} seconds' && sleep ${local.slowest_seconds}"
  }
}

resource "terraform_data" "near" {
  for_each = local.near_steps

  triggers_replace = terraform_data.trigger.output

  provisioner "local-exec" {
    command = "echo 'near ${each.key}: sleeping ${each.value} seconds' && sleep ${each.value}"
  }
}

resource "terraform_data" "filler" {
  count = local.filler_count

  triggers_replace = terraform_data.trigger.output

  provisioner "local-exec" {
    command = "echo 'filler ${count.index}: sleeping ${local.filler_seconds} seconds' && sleep ${local.filler_seconds}"
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

output "timestamp" {
  value       = terraform_data.trigger.output
  description = "Timestamp of the last apply."
}
