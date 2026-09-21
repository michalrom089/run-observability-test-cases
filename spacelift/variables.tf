variable "repository" {
  type        = string
  description = "Name of the GitHub repository that holds the test cases."
  default     = "run-observability-test-cases"
}

variable "branch" {
  type        = string
  description = "Branch the stacks track."
  default     = "main"
}

variable "space_id" {
  type        = string
  description = "Space that holds the stacks."
  default     = "root"
}

variable "tofu_version" {
  type        = string
  description = "OpenTofu version the stacks run."
  default     = "1.10.6"
}

variable "autodeploy" {
  type        = bool
  description = "Apply tracked runs without a confirmation. Keep this on to let the error cases reproduce on their own."
  default     = true
}

variable "name_prefix" {
  type        = string
  description = "Prefix for the stack names. Change it to run a second copy of the set in the same account."
  default     = "run-obs"
}
