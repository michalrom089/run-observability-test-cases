# run-observability-test-cases

Terraform configurations that produce known run outcomes. Point a stack at one
project root and you get the same result on every run.

Every case uses `timestamp()` as a trigger, so every run plans a change. No run
is ever a no-op.

| Project root       | Plan     | Apply                        |
| ------------------ | -------- | ---------------------------- |
| `simple/`          | succeeds | succeeds                     |
| `single-error/`    | succeeds | fails with one error         |
| `multiple-errors/` | succeeds | fails with two errors        |

`spacelift/` is not a test case. It creates one Spacelift stack per case. See
[Setting up the stacks](#setting-up-the-stacks).

## Cases

### `simple/`

The control case. A `terraform_data` trigger and a `random_id` that depends on
it. The apply always succeeds and the outputs change on every run.

### `single-error/`

Adds one `terraform_data` resource with a `local-exec` provisioner that exits 1.
The apply stops with one error:

```
Error: local-exec provisioner error
  with terraform_data.fail,
Error running command 'echo 'resource failing on purpose' && exit 1': exit status 1.
```

### `multiple-errors/`

Adds two `terraform_data` resources, `fail_a` and `fail_b`. Neither depends on
the other, so Terraform runs them in parallel and the apply reports two errors.

Each provisioner sleeps 5 seconds before it exits. Without the sleep, the first
failure can land before Terraform starts the second resource, which gives you
one error instead of two.

Set `-parallelism=1` and only `fail_a` fails. Use that if you want to compare
sequential and parallel failure reporting.

## Requirements

Terraform 1.4 or later, for the `terraform_data` resource. OpenTofu works too.
The only provider is `hashicorp/random`.

## Running a case locally

```bash
cd single-error
terraform init
terraform apply
```

## Setting up the stacks

`spacelift/` creates one OpenTofu stack per test case with the Spacelift
Terraform provider. The stack name is `run-obs-<project root>`.

```bash
cd spacelift
export SPACELIFT_API_KEY_ENDPOINT=https://<account>.app.spacelift.io
export SPACELIFT_API_KEY_ID=<id>
export SPACELIFT_API_KEY_SECRET=<secret>

terraform init
terraform apply
```

The stacks autodeploy, so every tracked run applies on its own and the error
cases reproduce without you confirming anything. Set `-var autodeploy=false` to
stop runs at Unconfirmed.

To add a case, add a directory and one entry to `locals.projects` in
`spacelift/main.tf`.

### Variables

| Name           | Default                         | Purpose                                |
| -------------- | ------------------------------- | -------------------------------------- |
| `repository`   | `run-observability-test-cases`  | Repository the stacks track            |
| `branch`       | `main`                          | Branch the stacks track                |
| `space_id`     | `root`                          | Space that holds the stacks            |
| `tofu_version` | `1.10.6`                        | OpenTofu version the stacks run        |
| `autodeploy`   | `true`                          | Apply tracked runs without confirming  |
| `name_prefix`  | `run-obs`                       | Prefix for the stack names             |

### Running it as an administrative stack

Point a stack at the `spacelift/` project root and set `administrative = true`.
Spacelift then manages the test stacks from a run instead of from your machine.
