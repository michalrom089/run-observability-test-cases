variable "repository" {
  type        = string
  description = "Name of the GitHub repository that holds the test cases."
  default     = "run-observability-test-cases"
}

variable "git_url" {
  type        = string
  description = "HTTPS URL of the repository. The stacks read it through the raw Git vendor, so the account needs no VCS integration."
  default     = "https://github.com/michalrom089/run-observability-test-cases.git"
}

variable "git_namespace" {
  type        = string
  description = "Namespace the raw Git vendor shows next to the repository name. Cosmetic only."
  default     = "michalrom089"
}

variable "branch" {
  type        = string
  description = "Branch the stacks track."
  default     = "main"
}

variable "parent_space_id" {
  type        = string
  description = "Space that holds the test case space."
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

variable "trigger_runs" {
  type        = bool
  description = "Start one run per test case after the stack is created. The run fires once, at create."
  default     = true
}

variable "slow_seconds" {
  type        = number
  description = "Seconds a slow run sleeps. The runs after slow_after get it as TF_VAR_sleep_seconds."
  default     = 300
}

variable "name_prefix" {
  type        = string
  description = "Prefix for the stack names. A second copy of the set in the same account also needs a different parent_space_id, because the space name is fixed."
  default     = "run-obs"
}

variable "worker_pool_id" {
  type        = string
  description = "Private worker pool for slow-provider-install-private. null leaves that stack out."
  default     = null
}
