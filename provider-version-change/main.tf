terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# pin-random.sh pins the version above per run. Each run of the stack sets a
# different RANDOM_VERSION, so every run after the first changes the version.

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
