# AGENT.md

Instructions for an agent working in this repository.

## What this repository is

A set of Terraform configurations that produce known run outcomes. Each project
root is one test case. Point a Spacelift stack at a project root and every run
gives the same result.

The repository exists to test run reporting, not to manage real infrastructure.
`hashicorp/random` and `terraform_data` are the only resources. Nothing here
costs money and nothing here has a real backend.

## Layout

| Path               | Purpose                                             |
| ------------------ | --------------------------------------------------- |
| `simple/`          | Test case. Plan and apply both succeed.              |
| `single-error/`    | Test case. Apply fails with one error.               |
| `multiple-errors/` | Test case. Apply fails with two errors in parallel.  |
| `slow-runs/`       | Test case. Apply succeeds. Later runs are slow.      |
| `spacelift/`       | Not a test case. Creates the space and the stacks.   |

## Rules that every test case follows

Break one of these and the case stops testing what it claims to test.

1. **Every case changes on every run.** Each `main.tf` has a
   `terraform_data.trigger` with `input = timestamp()`. Other resources depend
   on it through `keepers`. No run is ever a no-op.
2. **Failures happen at apply, not at plan.** A case fails through a
   `local-exec` provisioner that exits 1. `terraform validate` and
   `terraform plan` must succeed in every case.
3. **Parallel failures need a sleep.** In `multiple-errors/`, each provisioner
   sleeps 5 seconds before it exits. Without the sleep the first failure can
   land before Terraform starts the second resource, and the apply reports one
   error instead of two.
4. **A repeating provisioner needs `triggers_replace`.** A `local-exec`
   provisioner only runs when the resource is created. `input = ...` updates the
   resource in place, so the provisioner never runs again. `single-error/` and
   `multiple-errors/` get away with `input` because a failed provisioner taints
   the resource and the next apply replaces it. `slow-runs/` succeeds, so it
   must use `triggers_replace`.
5. **Failing resources do not depend on each other.** `fail_a` and `fail_b` both
   depend on the trigger and on nothing else. That is what lets Terraform run
   them at the same time.
6. **The README table is the contract.** Change a case, change the table.

## Adding a test case

1. Create a directory named after the outcome it produces.
2. Copy `simple/main.tf` as the starting point and keep the trigger.
3. Add one entry to `locals.stacks` in `spacelift/main.tf`. The key is the stack
   name suffix. Set `project_root` to the directory and `runs` to the number of
   runs the stack starts with. The stack joins the space on its own.
4. Add a row to the table in `README.md`.
5. Verify the case. See below.

`spacelift_run` starts the runs on the new stack. You do not trigger them. Set
`runs = 0` for a stack that must stay empty. Set `slow_after = N` to keep the
first N runs fast and give the rest `TF_VAR_sleep_seconds`, which only
`slow-runs/` reads.

## Verifying a change

Run these before you commit. Apply every case you touched and read the output.
A case that does not produce its documented outcome is a broken case.

```bash
terraform fmt -recursive -check

cd <case>
terraform init
terraform apply -auto-approve
```

Expected output:

- `simple` prints `Apply complete!`
- `single-error` prints one `Error: local-exec provisioner error`
- `multiple-errors` prints two, for `fail_a` and `fail_b`
- `slow-runs` prints `sleeping 0 seconds` and `Apply complete!`. Run it twice.
  The second apply must print the sleep again, not `0 changed`.

Delete `.terraform/`, `.terraform.lock.hcl` and the state files afterwards.
They are gitignored, but a stray state file makes the next run a no-op.

## The `spacelift/` directory

It creates the stacks with the `spacelift-io/spacelift` provider. One
`spacelift_stack` resource with `for_each` over `locals.stacks`.

`locals.stacks` is keyed by the stack name suffix, not by the project root. Two
stacks can share a project root. `run-obs-simple` and `run-obs-simple-no-runs`
both run `simple/` and differ only in their run count. `locals.runs` flattens
the map into one entry per run, which `spacelift_run` then creates.

The stacks sit in their own space. `spacelift_space.test_cases` creates it under
the space that `var.parent_space_id` names. The space takes its name from
`var.repository`, so it matches this repository. Every stack name starts with
`var.name_prefix`, which is `run-obs`. It inherits the entities of its parent, so the stacks still
see the contexts and the policies attached above.

The stacks read the repository through the raw Git vendor. `raw_git` takes the
public HTTPS URL from `var.git_url`. The account needs no VCS integration, so
the config works in any account. Keep the block.

A bootstrap stack applies this directory. `README.md` holds the `spacectl api`
commands that create it. The bootstrap stack needs the `space-admin` role
attached in `root`. `administrative = true` is deprecated. Use
`spacelift_role_attachment` or the `stackRoleBindingCreate` mutation.

**Do not apply it without asking.** An apply creates real stacks in a real
Spacelift account. `terraform init` and `terraform validate` are safe.

Keep the `opentofu` block on the stack resource. The cases run on OpenTofu.
The block makes a native OpenTofu stack. It replaces
`terraform_workflow_tool = "OPEN_TOFU"` and conflicts with every `terraform_*`
attribute. The account needs the `opentofu-backend` feature flag.

## Writing style

Short sentences, one idea each. Active voice. Plain words. Say what a thing
does, not what it enables. Keep identifiers and product names exact.
