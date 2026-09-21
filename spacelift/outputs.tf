output "stack_ids" {
  value       = { for key, stack in spacelift_stack.test_case : key => stack.id }
  description = "Stack ID for each test case, keyed by project root."
}
