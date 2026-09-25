variable "trigger" {
  type        = string
  description = "Replaces every resource when it changes."
}

variable "sleeps" {
  type        = map(number)
  description = "Seconds each instance sleeps, keyed by its for_each key."
}

resource "terraform_data" "a_resource_name_that_keeps_going_long_after_it_should_have_stopped" {
  for_each = var.sleeps

  triggers_replace = var.trigger

  provisioner "local-exec" {
    command = "sleep ${each.value}"
  }
}
