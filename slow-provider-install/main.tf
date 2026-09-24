terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    # A large provider. No resource uses it, so the plan never configures it
    # and needs no credentials. reinstall-providers.sh installs it again and
    # again, so init spends more than 10 seconds on it.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

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
