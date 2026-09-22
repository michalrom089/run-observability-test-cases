output "stack_ids" {
  value       = { for key, stack in spacelift_stack.test_case : key => stack.id }
  description = "Stack ID for each test case, keyed by the stack name suffix."
}

output "run_counts" {
  value = {
    for key, stack in local.stacks : key => {
      total = stack.runs
      fast  = coalesce(stack.slow_after, stack.runs)
      slow  = stack.runs - coalesce(stack.slow_after, stack.runs)
    }
  }
  description = "Runs each stack starts at create, split into fast and slow."
}

output "space_id" {
  value       = spacelift_space.test_cases.id
  description = "Space that holds the test case stacks."
}
