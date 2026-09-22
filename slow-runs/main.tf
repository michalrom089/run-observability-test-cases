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
  description = "Seconds the apply sleeps before it finishes."
  default     = 0
}

# The timestamp forces replacement on every apply, so every run has work to do.
resource "terraform_data" "trigger" {
  input = timestamp()
}

# The apply always succeeds. Only the time it takes changes.
resource "terraform_data" "work" {
  # triggers_replace, not input. An input change updates the resource in place
  # and a provisioner only runs at create, so the sleep would never repeat.
  triggers_replace = terraform_data.trigger.output

  provisioner "local-exec" {
    command = "echo 'sleeping ${var.sleep_seconds} seconds' && sleep ${var.sleep_seconds}"
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
  description = "Seconds the apply slept."
}

output "timestamp" {
  value       = terraform_data.trigger.output
  description = "Timestamp of the last apply."
}
