# Not a module of the case. A hook runs `tofu -chdir=pinned init` to install
# an older hashicorp/random than the root module does. Nothing plans or
# applies this directory.
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "= 3.5.1"
    }
  }
}
