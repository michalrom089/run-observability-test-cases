terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

# pinned/ requires an older version of the same provider. A hook runs a second
# `tofu init` in it, so the run resolves hashicorp/random at two versions.

# The timestamp forces replacement on every apply, so every run has work to do.
resource "terraform_data" "trigger" {
  input = timestamp()
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
