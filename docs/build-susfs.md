# Build a SUSFS kernel

[← Home](../README.md) · [Workflows](workflows.md) · **Build a SUSFS kernel** · [Master script](master-script.md) · [Secrets and outputs](secrets-and-outputs.md) · [Forking](forking.md) · [Troubleshooting](troubleshooting.md) · [History](history.md)

---

`build.yml` and `build-custom.yml` build violet with SUSFS. They are the only workflows that use the framework in `scripts/`, `devices/` and `config.env`.

## Contents

- [Run it](#run-it)
- [What it does](#what-it-does)
- [Variants](#variants)
- [Outputs](#outputs)
- [Framework layout](#framework-layout)
- [Adding a device](#adding-a-device)

## Run it

**`build.yml`** (fixed to violet):

1. Go to **Actions** → **Build XCalibur-XF SUSFS Kernel (violet)**.
2. Click **Run workflow**.
3. Set **create_release** if you want a GitHub Release. Leave it `false` otherwise.

**`build-custom.yml`** (any device, any setting):

1. Go to **Actions** → **Build Custom SUSFS Kernel**.
2. Fill in only the inputs you want to change. Leave the rest empty to use `devices/<device>.json`.
3. Click **Run workflow**. The log shows which inputs were applied over the JSON.

The full input list is in [Workflows](workflows.md#build-customyml-build-custom-susfs-kernel).

## What it does

- **Matrix:** two jobs, one for `ksu` and one for `nsu`. `fail-fast` is off, so one failing variant doesn't stop the other.
- **Steps:**
  1. Installs dependencies.
  2. Resolves the device config. In `build-custom.yml`, inputs are applied over the JSON here.
  3. Clones the kernel source.
  4. Restores the Clang and ccache caches.
  5. Runs `env.sh`, `variant.sh` and `compile.sh`.
  6. Uploads the zip and debug artifacts.
  7. Sends the zip to Telegram on success, or the last 35 log lines on failure.
- **Release job** (only if `create_release` is `true`): gathers every `xcalibur-xf-*` artifact and publishes one release. The release notes show the KernelSU and SuSFS versions from the `ksu` build.

## Variants

| Variant | What it is |
| :--- | :--- |
| `ksu` | KernelSU and SuSFS, applied by `scripts/ksu.sh` |
| `nsu` | Stock kernel with no KernelSU |

## Outputs

| Artifact | Contents |
| :--- | :--- |
| `xcalibur-xf-<device>-<variant>` | Flashable zip |
| `debug-<device>-<variant>` | Build log and final `.config` |
| `xcalibur-xf-<device>-ksu-versions` | KernelSU and SuSFS versions (`ksu` only) |
| `xcalibur-xf-<device>-<variant>-rejects` | Patch reject files (failed builds only) |

See [Secrets and outputs](secrets-and-outputs.md) for where these end up.

## Framework layout

```
config.env            KernelSU and SuSFS repo URLs and pinned commits
devices/<name>.json   Device config: kernel repo and branch, defconfig, kernel version,
                      Clang version and branch, AnyKernel3 repo and branch, variants
devices/patches/      Device-specific fixes applied during ksu builds
scripts/master.sh     Shared steps for every workflow (see Master script)
scripts/common.sh     Logging, JSON reader, retrying fetch, kernel version check
scripts/env.sh        Fetches the pinned Clang and exports the build environment
scripts/variant.sh    Runs ksu.sh for the ksu variant; nothing extra for nsu
scripts/ksu.sh        Clones KernelSU and SuSFS at their pins, applies SuSFS,
                      fixes exports, writes the config fragment
scripts/compile.sh    Builds the kernel, merges the fragment, packages the zip
```

## Adding a device

1. Create `devices/<name>.json` with the same fields as `devices/violet.json`. The top-level key must match the file name.
2. Set `kernel_version` to the `VERSION.PATCHLEVEL` in the kernel's `Makefile`. The preflight step fails the build if they differ.
3. Set `clang_branch` to the googlesource branch that clang version was published under. `env.sh` won't guess it.
4. If the SuSFS patch leaves a reject in a file your kernel changes differently, add a port patch under `devices/patches/<name>-<file>.patch` and apply it in `ksu.sh`, as done for violet's `fs/proc/cmdline.c`.
5. `build-custom.yml` takes the device name as an input. `build.yml` is hardcoded to violet, so use `build-custom.yml` for a second device, or copy `build.yml` and change the device.

---

[← Workflows](workflows.md) · [Next: Master script →](master-script.md)
