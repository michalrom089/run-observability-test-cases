variable "trigger" {
  type        = string
  description = "Replaces every resource when it changes."
}

# count gives the address an index after the long name.
resource "terraform_data" "a_resource_indexed_by_count_whose_name_is_also_far_too_long" {
  count = 2

  triggers_replace = var.trigger

  provisioner "local-exec" {
    command = "sleep 1"
  }
}

module "an_inner_module_call_with_an_even_longer_name_than_the_module_that_calls_it" {
  source = "../inner"

  trigger = var.trigger

  # The keys end up in the addresses. Each tests a different kind of long key.
  sleeps = {
    "a-for-each-key-that-is-long-enough-to-wrap-on-its-own-in-most-table-cells" = 4
    "a key with spaces, commas, a slash / and \"double quotes\""                = 3
    "ключ-с-юникодом-und-umlauts-äöü-and-an-emoji-🚀"                            = 2
  }
}
