# Build a BakaSU SUSFS kernel

`bakasu.yml` (BakaSU Kernel Build) builds a device with BakaSU and SUSFS. The default device is violet, and every input is optional.

## Contents

- [Run it](#run-it)
- [What it does](#what-it-does)
- [Variants](#variants)
- [Outputs](#outputs)
- [Framework layout](#framework-layout)
- [Adding a device](#adding-a-device)

---

## Run it

Actions → *BakaSU Kernel Build* → *Run workflow*. Leave every input empty to build violet from its device file. Fill in an input to override that one value.

| Input | Empty means |
| :--- | :--- |
| `device_codename` | `violet` |
| `kernel_name`, `kernel_source`, `kernel_branch`, `defconfig_name`, `clang_version` | the value in `devices/<device>.json` |
| `build_nonksu` | `false`: only the `ksu` variant is built |
| `create_release` | `false`: no GitHub Release |

---

## What it does

1. **config:** resolves the device file, with any filled-in inputs applied on top.
2. **build:** clones the kernel source, links the preinstalled Clang, restores ccache, stages the BakaSU framework, checks the declared kernel version, and builds each selected variant.
3. **notify:** sends one Telegram start message, and one finish message with the files, or a failure message.
4. **release:** runs only with `create_release`.

BakaSU is pinned in `config.env`. A patch that doesn't apply to the kernel tree fails the build, and its rejects are uploaded as an artifact.

---

## Variants

| Variant | What it is |
| :--- | :--- |
| `ksu` | BakaSU with SUSFS. Always built |
| `nsu` | A non-root build without SUSFS. Built only with `build_nonksu` |

The variant is part of the zip name, so both variants can be downloaded from the same run.

---

## Outputs

- A flashable AnyKernel3 zip per variant, as the artifact `xcalibur-xf-<device>-<variant>`.
- Debug logs, as `debug-<device>-<variant>`.
- Patch rejects, as `xcalibur-xf-<device>-<variant>-rejects`, when a patch fails.
- Version info, as `xcalibur-xf-<device>-<variant>-versions`.

See [Secrets and outputs](secrets-and-outputs.md) for the full list.

---

## Framework layout

| Path | Contents |
| :--- | :--- |
| `devices/<name>.json` | Device settings: kernel repo, branch, defconfig, kernel version, kernel name, Clang, AnyKernel3 |
| `devices/patches/` | Per-device patches, such as the cmdline SUSFS port |
| `config.env` | Pinned BakaSU and SUSFS commits |
| `patches/ksu/` | KernelSU patches applied by `scripts/ksu-fetch.sh` |
| `scripts/` | `resolve-device.py`, `master.sh`, `ksu.sh`, `compile.sh`, `notify.sh`, and the rest |
| `docker/build-env/` | The build image definition |

---

## Adding a device

1. Copy `devices/violet.json` to `devices/<name>.json` and set `kernel_repo`, `kernel_branch`, `defconfig`, `kernel_version`, `kernel_name`, `clang_version`, and the AnyKernel3 repo and branch.
2. If the kernel's `fs/proc/cmdline.c` needs a SUSFS change that the common patch doesn't apply, add `devices/patches/<name>-cmdline-susfs-port.patch`.
3. Run `bakasu.yml` with `device_codename` set to `<name>`. Check the Telegram message and the artifacts.
