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

# The slowest resource has the shortest address, so the list of slowest
# resources starts with a short name and continues with long ones.
resource "terraform_data" "short" {
  triggers_replace = terraform_data.trigger.output

  provisioner "local-exec" {
    command = "sleep 5"
  }
}

# Two module levels with long call names. Every resource inside gets both names
# in its address.
module "a_module_call_name_that_is_long_on_purpose_to_stretch_the_address_column" {
  source = "./modules/outer"

  trigger = terraform_data.trigger.output
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
