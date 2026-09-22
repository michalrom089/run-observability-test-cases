output "stack_ids" {
  value       = { for key, stack in spacelift_stack.test_case : key => stack.id }
  description = "Stack ID for each test case, keyed by the stack name suffix."
}

output "run_counts" {
  value       = { for key, stack in local.stacks : key => stack.runs }
  description = "Number of runs each stack starts at create."
}

output "space_id" {
  value       = spacelift_space.test_cases.id
  description = "Space that holds the test case stacks."
}
