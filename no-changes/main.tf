terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# No timestamp anywhere. This is the one case that breaks the trigger rule on
# purpose. The first apply creates the resources. Every apply after it plans
# nothing and reports no changes.
resource "terraform_data" "fixed" {
  input = "no-changes"
}

resource "random_id" "output" {
  byte_length = 7

  keepers = {
    fixed = terraform_data.fixed.output
  }
}

output "random_id" {
  value       = random_id.output.hex
  description = "Random ID. It keeps the value the first apply gave it."
}

output "fixed" {
  value       = terraform_data.fixed.output
  description = "Fixed input. It never changes, so neither does the plan."
}
