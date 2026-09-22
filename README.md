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

`spacelift/` is not a test case. It creates five stacks from those three project
roots. Two of them hold no runs at all, which is its own thing to report on.

| Stack                          | Project root       | Runs |
| ------------------------------ | ------------------ | ---- |
| `run-obs-simple`               | `simple/`          | 3    |
| `run-obs-single-error`         | `single-error/`    | 3    |
| `run-obs-multiple-errors`      | `multiple-errors/` | 3    |
| `run-obs-simple-no-runs`       | `simple/`          | 0    |
| `run-obs-single-error-no-runs` | `single-error/`    | 0    |

## Getting started

This creates one bootstrap stack. The bootstrap stack creates the space and the
three test stacks. You run nothing on your machine after step 3.

The commands need spacectl v1.20.0 or later. See
[Requirements](#requirements). They use your spacectl profile, so run
`spacectl profile login <alias>` first if you have none.

**1. Create the bootstrap stack.** It reads this repository over the raw Git
vendor, so your account needs no VCS integration.

```bash
spacectl api --variables '{
  "input": {
    "name": "run-obs-bootstrap",
    "description": "Creates the run observability test case space and stacks.",
    "provider": "GIT",
    "repository": "run-observability-test-cases",
    "repositoryURL": "https://github.com/michalrom089/run-observability-test-cases.git",
    "namespace": "michalrom089",
    "branch": "main",
    "projectRoot": "spacelift",
    "space": "root",
    "autodeploy": true,
    "administrative": false,
    "labels": ["run-observability", "bootstrap"],
    "vendorConfig": {
      "opentofu": { "version": "1.10.6", "workflowTool": "OPENTOFU" }
    }
  },
  "manageState": true
}' 'mutation CreateBootstrap($input: StackInput!, $manageState: Boolean!) {
  stackCreate(input: $input, manageState: $manageState) { id name }
}'
```

**2. Give the stack permission to create the space and the stacks.** Attach the
`space-admin` system role in `root`. `administrative = true` is deprecated.

```bash
ROLE_ID=$(spacectl api '{ roles { id slug } }' --raw \
  | jq -r '.data.roles[] | select(.slug == "space-admin") | .id')

spacectl api --variables "{
  \"input\": {
    \"stackID\": \"run-obs-bootstrap\",
    \"roleID\": \"$ROLE_ID\",
    \"spaceID\": \"root\"
  }
}" 'mutation AttachRole($input: StackRoleBindingInput!) {
  stackRoleBindingCreate(input: $input) { id }
}'
```

`stackID` takes the stack slug. You need admin access to `root` to read the role
and to attach it.

**3. Run it.**

```bash
spacectl stack deploy --id run-obs-bootstrap
```

The run creates the space and the five test stacks. It also starts the runs that
the table above lists, so the cases produce their outcomes without you doing
anything. The two `-no-runs` stacks stay empty on purpose.

To run them again later:

```bash
for c in simple single-error multiple-errors; do
  spacectl stack deploy --id "run-obs-$c"
done
```

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

[Getting started](#getting-started) needs spacectl v1.20.0 or later. It calls
the `api` command, which arrived in that release. `spacectl version` prints what
you have. On macOS this upgrades it:

```bash
brew upgrade --cask spacelift-io/spacelift/spacectl
```

Homebrew ships spacectl as a cask, not a formula. If it refuses to load the cask
from an untrusted tap, run `brew trust spacelift-io/spacelift` once.

## Running a case locally

```bash
cd single-error
terraform init
terraform apply
```

## Setting up the stacks

`spacelift/` creates one OpenTofu stack per test case with the Spacelift
Terraform provider. The stack name is `run-obs-<project root>`. The stacks live
in their own space, `run-observability-test-cases`, under the root space.

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

To add a case, add a directory and one entry to `locals.stacks` in
`spacelift/main.tf`. The key is the stack name suffix. `project_root` names the
directory and `runs` says how many runs the stack starts with.

### Variables

| Name              | Default                        | Purpose                               |
| ----------------- | ------------------------------ | ------------------------------------- |
| `repository`      | `run-observability-test-cases` | Repository the stacks track           |
| `git_url`         | the HTTPS URL of this repo     | Repository URL for the raw Git vendor |
| `git_namespace`   | `michalrom089`                 | Namespace shown next to the repo      |
| `branch`          | `main`                         | Branch the stacks track               |
| `parent_space_id` | `root`                         | Space that holds the test case space  |
| `tofu_version`    | `1.10.6`                       | OpenTofu version the stacks run       |
| `autodeploy`      | `true`                         | Apply tracked runs without confirming |
| `trigger_runs`    | `true`                         | Start one run per case at create      |
| `name_prefix`     | `run-obs`                      | Prefix for the stack names            |

### Running it from a stack

Point a stack at the `spacelift/` project root. Spacelift then manages the space
and the test stacks from a run instead of from your machine.

That stack needs permission to create them. `administrative = true` is
deprecated. Attach the `space-admin` system role to the stack instead:

```hcl
data "spacelift_role" "space_admin" {
  slug = "space-admin"
}

resource "spacelift_role_attachment" "bootstrap" {
  stack_id = "run-obs-bootstrap"
  role_id  = data.spacelift_role.space_admin.id
  space_id = "root"
}
```

`stack_id` takes the stack slug, not the ULID. `space_id` is `root`, because the
stack creates a space under root. You need admin access to `root` to read the
role and to attach it.
