# run-observability-test-cases

Terraform configurations that produce known run outcomes. Point a stack at one
project root and you get the same result on every run.

Most cases use `timestamp()` as a trigger, so every run plans a change.
`no-changes/` is the exception. It has no trigger, so every run after the first
is a no-op.

| Project root                 | Plan     | Apply                                      |
| ---------------------------- | -------- | ------------------------------------------ |
| `simple/`                    | succeeds | succeeds                                   |
| `single-error/`              | succeeds | fails with one error                       |
| `multiple-errors/`           | succeeds | fails with two errors                      |
| `slow-runs/`                 | succeeds | succeeds, after a sleep                    |
| `no-changes/`                | succeeds | succeeds, changing nothing                 |
| `provider-version-change/`   | succeeds | succeeds, provider version moves per run   |
| `provider-version-conflict/` | succeeds | succeeds, a hook resolves a second version |
| `slow-provider-install/`     | succeeds | succeeds, after a slow init                |

`spacelift/` is not a test case. It creates up to twelve stacks from those
eight project roots. Two hold no runs at all, one changes pace part way through
and one goes quiet after its first run. The last five each produce one finding
type. Each is its own thing to report on.

| Stack                                          | Project root                 | Runs           |
| ---------------------------------------------- | ---------------------------- | -------------- |
| `run-obs-simple`                               | `simple/`                    | 3              |
| `run-obs-single-error`                         | `single-error/`              | 3              |
| `run-obs-multiple-errors`                      | `multiple-errors/`           | 3              |
| `run-obs-simple-no-runs`                       | `simple/`                    | 0              |
| `run-obs-single-error-no-runs`                 | `single-error/`              | 0              |
| `run-obs-no-changes`                           | `no-changes/`                | 3              |
| `run-obs-slow-runs`                            | `slow-runs/`                 | 3 fast, 3 slow |
| `run-obs-provider-version-change`              | `provider-version-change/`   | 3              |
| `run-obs-provider-version-conflict-one-state`  | `provider-version-conflict/` | 1              |
| `run-obs-provider-version-conflict-two-states` | `provider-version-conflict/` | 1              |
| `run-obs-slow-provider-install`                | `slow-provider-install/`     | 1              |
| `run-obs-slow-provider-install-private`        | `slow-provider-install/`     | 1              |

The last five stacks cover the findings that the backend reports for a run.

| Stack                                          | Finding                            | Severity |
| ---------------------------------------------- | ---------------------------------- | -------- |
| `run-obs-provider-version-change`              | `ProviderVersionChange`, runs 2, 3 | MINOR    |
| `run-obs-provider-version-conflict-one-state`  | `ProviderVersionConflict`          | MAJOR    |
| `run-obs-provider-version-conflict-two-states` | `ProviderVersionConflict`          | MAJOR    |
| `run-obs-slow-provider-install`                | `SlowProviderInstallCacheDisabled` | MINOR    |
| `run-obs-slow-provider-install-private`        | `SlowProviderInstallCacheDisabled` | MINOR    |

`run-obs-slow-provider-install-private` needs a private worker pool. It exists
only when you set `worker_pool_id`.

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

The run creates the space and the test stacks. It also starts the runs that
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

### `no-changes/`

The one case with no `timestamp()` trigger. The first apply creates a
`terraform_data` and a `random_id`. Every apply after it prints `No changes.
Your infrastructure matches the configuration.` and touches nothing.

The stack starts three runs. Run one applies. Runs two and three are no-ops.

### `provider-version-change/`

`pin-random.sh` runs before init. It writes `random_override.tf`, which pins
`hashicorp/random` to `RANDOM_VERSION`. Without the variable the script does
nothing.

The stack starts three runs and gives each run its own `RANDOM_VERSION` in the
run environment: 3.6.0, 3.6.3 and 3.7.1. The order of the runs does not matter.
Every run after the first uses a different version than the tracked run before
it, so it reports `ProviderVersionChange`.

### `provider-version-conflict/`

The root module requires `hashicorp/random ~> 3.7`. `pinned/` requires `= 3.5.1`.
Nothing plans or applies `pinned/`. A hook runs `tofu -chdir=pinned init`, so
the run resolves the provider at two versions and reports
`ProviderVersionConflict`.

The worker traces every `tofu` command in a hook, and tags it with the state
the hook runs in. The hook decides which cause the finding names:

- `-one-state` runs it `after_init`. Initializing resolves both versions.
- `-two-states` runs it `before_plan`. Initializing resolves one version,
  planning the other.

### `slow-provider-install/`

Requires `hashicorp/aws` next to `hashicorp/random`. No resource uses it, so
the plan never configures it and needs no credentials. The stacks set no
`TF_PLUGIN_CACHE_DIR`.

The finding needs a provider to spend 10 seconds or longer installing in one
state. The worker adds up every install of one provider in one state. An
`after_init` hook runs `reinstall-providers.sh`. It deletes
`.terraform/providers` and runs `tofu init` again, `REINSTALL_PASSES` times
(default 10). Every pass downloads `hashicorp/aws` again, so Initializing spends
ten installs on it. The case needs no slow network.

The public stack gets the custom runner image recommendation. The private stack
gets the `TF_PLUGIN_CACHE_DIR` recommendation.

### `slow-runs/`

The apply always succeeds. `var.sleep_seconds` decides how long it takes, and
the default is 0. The stack's first three runs leave it alone and finish fast.
The runs after that carry `TF_VAR_sleep_seconds` in their run environment, so
they sleep and a duration alert has something to catch.

`spacelift/main.tf` sets that environment, not this directory. `slow_after = 3`
on the stack says how many runs stay fast, and `var.slow_seconds` says how long
the rest sleep.

## Requirements

Terraform 1.4 or later, for the `terraform_data` resource. OpenTofu works too.
Most cases use only `hashicorp/random`. `slow-provider-install/` also downloads `hashicorp/aws`.

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
| `slow_seconds`    | `300`                          | Seconds a slow run sleeps             |
| `trigger_runs`    | `true`                         | Start one run per case at create      |
| `name_prefix`     | `run-obs`                      | Prefix for the stack names            |
| `worker_pool_id`  | `null`                         | Private pool for `-private` stack     |

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
