terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# The timestamp forces replacement on every apply, so every run has work to do.
resource "terraform_data" "trigger" {
  input = timestamp()
}

# Two resources fail. Neither depends on the other, so Terraform runs them in
# parallel. The sleep keeps both in flight, so the apply reports two errors.
# With -parallelism=1 only the first one fails.
resource "terraform_data" "fail_a" {
  input = terraform_data.trigger.output

  provisioner "local-exec" {
    command = "echo 'resource A failing on purpose' && sleep 5 && exit 1"
  }
}

resource "terraform_data" "fail_b" {
  input = terraform_data.trigger.output

  provisioner "local-exec" {
    command = "echo 'resource B failing on purpose' && sleep 5 && exit 1"
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
