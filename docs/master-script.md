# Master script

`scripts/master.sh` holds the steps the workflows share. Each workflow calls it with a command name and arguments.

## Commands

| Command | Arguments | What it does |
| :--- | :--- | :--- |
| `clang <version> [dest-dir]` | Clang version (e.g. `clang-r596125`), target directory (default `toolchains/<version>`) | Downloads a Clang toolchain from AOSP googlesource. Skips the download if `<dest>/bin/clang` already exists. Used when the preinstalled one is missing |
| `ksu-setup <kernel-dir> <ksu-type> <defconfig> [susfs]` | kernel dir, `KernelSU` or `None`, defconfig path, `true` or `false` | Fetches the KernelSU source and patches, applies SUSFS when `susfs` is `true`, integrates NoMount when enabled, and appends the kernel config options to the defconfig |
| `compile <clang-version> <defconfig> <kernel-dir> <log>` | Clang version (e.g. `clang-r596125`), defconfig target, kernel dir, build log | Builds the kernel with ccache and the Clang under `toolchains/<version>/`. Appends `-susfs` to `LOCALVERSION` when SUSFS is in the config. Writes the log |
| `anykernel <boot-dir> <kernel-name> <device> <label> <clang-bin>` | boot dir, kernel name, device, `KernelSU` or `None`/`NonKSU`, Clang bin dir | Packages the kernel images into an AnyKernel3 zip and prints its name on stdout |
| `prune-ccache <prefix>` | cache key prefix | Keeps the newest ccache entry under that prefix and deletes the rest |
| `help` | none | Prints the usage header |

`None` never applies SUSFS. A `KernelSU` build with `susfs` set to `false` leaves SUSFS out.

## Environment

Commands read these from the calling workflow's `env:` block:

- `CCACHE_DIR`, `CCACHE_MAXSIZE`, `CCACHE_BASEDIR`, `CCACHE_NOHASHDIR` for the compile step
- `REQUIRE_KSU_TAMPER`, set from the root type. When `true`, the compile step fails if the final `.config` lost `CONFIG_KSU_TAMPER_SYSCALL_TABLE`
- `NOMOUNT_ENABLED`, set from the `nomount` input. NoMount is integrated only when this is `true`, `NOMOUNT_TAG` is set, and the root type is `KernelSU`
- `GH_TOKEN` for `prune-ccache`
- `AK3_REPO`, `AK3_BRANCH` for `anykernel`. Both default to the AnyKernel3 fork in the Forking table

## Rules

- A missing argument stops the step with a usage message.
- Workflows pass inputs through `env:`, never by pasting them into shell code.
- A step belongs in `master.sh` when two or more workflows need it. Steps unique to one workflow stay in that workflow.

## Where each workflow uses it

| Workflow | Commands used |
| :--- | :--- |
| `bakasu.yml` | `clang` (only when `env.sh` finds no preinstalled toolchain), `prune-ccache`. Packaging and the compile step run through `scripts/env.sh`, `variant.sh`, `ksu.sh` and `compile.sh`, not `master.sh` |
| `kernelsu.yml` | `clang`, `ksu-setup`, `compile`, `anykernel`, `prune-ccache` |
| `build-manager.yml` | none (self-contained; fetches KernelSU with `ksu-fetch.sh`) |
| `build-env.yml` | none (Dockerfile) |
| `release.yml` | none (calls `kernelsu.yml`) |

## Scripts outside `master.sh`

The BakaSU path uses its own scripts. Each one is listed here so you know where to look:

| Script | Used by | What it does |
| :--- | :--- | :--- |
| `common.sh` | Most scripts | Logging (`log`, `warn`, `die`), the device-JSON reader (`read_field`), `verify_kernel_version` |
| `env.sh` | `bakasu.yml` | Reads the device file, checks `arch` is `arm64`, fetches Clang if needed, sets the cross-compile environment |
| `variant.sh` | `bakasu.yml` | Runs `ksu.sh` for the `ksu` variant. Does nothing for `nsu` |
| `ksu.sh` | `variant.sh` | Installs BakaSU at the resolved commit, applies the SUSFS patch, applies the device port if needed, exports static symbols, integrates NoMount when `NOMOUNT_TAG` is set, and writes the config fragment |
| `compile.sh` | `bakasu.yml` | Builds the kernel with the config fragment, checks NoMount, packages the AnyKernel3 zip, and writes the version files |
| `ksu-fetch.sh` | `ksu-setup`, `build-manager.yml` | Clones upstream KernelSU, applies `patches/ksu`, and links the driver into the kernel tree (or only writes the source when `KSU_DEST` is set) |
| `susfs-setup.sh` | `ksu-setup` (kernelsu path) | Applies the pinned SUSFS kernel patch and inline hooks, and the device port when needed |
| `nomount.sh` | `ksu.sh`, `ksu-setup` | Clones NoMount at `NOMOUNT_TAG` and runs its kernel setup |
| `resolve-device.py` | Config job of both build workflows | Merges non-empty inputs over `devices/<device>.json` and prints the resolved config |
| `ccache-summary.sh` | Both build workflows | Resets ccache counters and writes the hit rate to the job summary |

## Still inline

Steps that only one workflow uses stay in that workflow: the Manager Gradle steps, the release-notes composition, and the artifact uploads.

## `scripts/notify.sh`

Sends the Telegram messages. It does nothing when `TELEGRAM_BOT_TOKEN` or `TELEGRAM_CHAT_ID` is unset.

- `start <device> <kernel-name> <root-label> <compiler>` prints the start timestamp, which the finish message needs. The root label is `BakaSU`, `BakaSU + non-KSU`, `KernelSU` or `None`.
- `finish <device> <kernel-name> <compiler> <start-epoch> <glob:label>...` uploads each matching file, then sends the finish message. If any upload fails, it sends a warning message instead and exits with status 1.
- `fail <device> <kernel-name> <compiler> <start-epoch> <run-url>` sends the failure message.
