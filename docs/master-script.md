# Master script

`scripts/master.sh` holds the steps the workflows share. Each workflow calls it with a command name and arguments.

## Commands

| Command | Arguments | What it does |
| :--- | :--- | :--- |
| `deps` | none | Installs the apt build packages |
| `clang <version> <dir>` | Clang version, target directory | Downloads a Clang toolchain into `<dir>`. Used when the preinstalled one is missing |
| `ksu-setup <kernel-dir> <ksu-type> <defconfig> [susfs]` | kernel dir, `KernelSU` or `None`, defconfig path, `true` or `false` | Fetches the KernelSU source and patches, applies SUSFS when `susfs` is `true`, and appends the kernel config options |
| `compile <clang-dir> <defconfig> <kernel-dir> <log>` | Clang directory name, defconfig target, kernel dir, build log | Runs the kernel build and writes the log |
| `anykernel <boot-dir> <kernel-name> <device> <label> <clang-bin>` | boot dir, kernel name, device, `KernelSU` or `None`, Clang bin dir | Packages the kernel images into an AnyKernel3 zip and prints its name |
| `prune-ccache <prefix>` | cache key prefix | Deletes older ccache entries under that prefix |

`None` never applies SUSFS. A `KernelSU` build with `susfs` set to `false` leaves SUSFS out.

## Environment

Commands read these from the calling workflow's `env:` block:

- `CCACHE_DIR`, `CCACHE_MAXSIZE`, `CCACHE_BASEDIR`, `CCACHE_NOHASHDIR` for the compile step
- `REQUIRE_KSU_TAMPER`, set from the root type, for the compile step
- `GH_TOKEN` for `prune-ccache`

## Rules

- A missing argument stops the step with a usage message.
- Workflows pass inputs through `env:`, never by pasting them into shell code.
- A step belongs in `master.sh` when two or more workflows need it. Steps unique to one workflow stay in that workflow.

## Where each workflow uses it

| Workflow | Commands used |
| :--- | :--- |
| `bakasu.yml` | `clang`, `compile`, `anykernel`, `prune-ccache` |
| `kernelsu.yml` | `clang`, `ksu-setup`, `compile`, `anykernel`, `prune-ccache` |
| `build-manager.yml` | none (self-contained) |
| `build-env.yml` | none (Dockerfile) |
| `release.yml` | none (calls `kernelsu.yml`) |

## Still inline

Steps that only one workflow uses stay in that workflow: the Manager Gradle steps, the release-notes composition, and the artifact uploads.

## `scripts/notify.sh`

Sends the Telegram messages:

- `start <device> <kernel-name> <label> <clang>` prints the start timestamp, which the finish message needs.
- `finish <device> <kernel-name> <clang> <epoch> <glob:label>...` sends the finish message and attaches the matching files.
- `fail <device> <kernel-name> <clang> <epoch> <run-url>` sends the failure message.
