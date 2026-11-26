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
| `device_codename` | `violet` (the only option in the dropdown today) |
| `kernel_name`, `kernel_source`, `kernel_branch`, `defconfig_name` | the value in `devices/<device>.json` |
| `clang_version` | `default`: the value in `devices/<device>.json` |
| `build_nonksu` | `false`: only the `ksu` variant is built |
| `create_release` | `false`: no GitHub Release |

---

## What it does

1. **config:** resolves the device file, with any filled-in inputs applied on top (`scripts/resolve-device.py`).
2. **build:** clones the kernel source, links the preinstalled Clang when it exists, restores ccache, stages the builder files into the kernel tree, checks the declared kernel version, and builds each selected variant.
3. **notify:** sends one Telegram start message, and one finish message with the files, or a failure message.
4. **release:** runs only with `create_release`.
5. **cache cleanup:** after a successful build, deletes old ccache entries for the device and branch.

BakaSU follows `main` through `KSU_REPO_PIN` in `config.env`, so each run uses the latest commit. SUSFS and NoMount are pinned to commits or tags in the same file. A patch that doesn't apply to the kernel tree fails the build, and its rejects are uploaded as an artifact.

---

## Variants

| Variant | What it is |
| :--- | :--- |
| `ksu` | BakaSU with SUSFS. Always built |
| `nsu` | A non-root build without SUSFS. Built only with `build_nonksu` |

The zip name carries the label, `BakaSU` or `NonKSU`, plus `_SUSFS` on the BakaSU build. The variant name appears in the artifact names, so both variants can be downloaded from the same run.

---

## Outputs

- A flashable AnyKernel3 zip per variant, as the artifact `xcalibur-xf-<device>-<variant>`.
- Debug logs (build log and `.config`), as `debug-<device>-<variant>`.
- Patch rejects, as `xcalibur-xf-<device>-<variant>-rejects`, when a patch fails.
- Version info, as `xcalibur-xf-<device>-ksu-versions`. Only the `ksu` variant produces it.

See [Secrets and outputs](secrets-and-outputs.md) for the full list.

---

## Framework layout

| Path | Contents |
| :--- | :--- |
| `devices/<name>.json` | Device settings: `arch`, kernel repo, branch, defconfig, kernel version, kernel name, Clang version, AnyKernel3 repo and branch |
| `devices/patches/` | Per-device patches, such as the cmdline SUSFS port |
| `config.env` | BakaSU repo and branch (`main`), SUSFS repo and pinned commit, NoMount repo and tag (`NOMOUNT_TAG`, empty disables NoMount for BakaSU builds) |
| `patches/ksu/` | KernelSU patches applied by `scripts/ksu-fetch.sh` |
| `patches/susfs/Kconfig.susfs` | The SUSFS Kconfig block appended to KernelSU's Kconfig when it is missing |
| `scripts/` | `resolve-device.py`, `env.sh`, `variant.sh`, `ksu.sh`, `compile.sh`, `master.sh`, `notify.sh`, and the rest. See [Master script](master-script.md) |
| `.github/actions/` | `ccache-restore` and `ccache-save`, the shared ccache steps |
| `docker/build-env/` | The build image definition |

---

## Adding a device

1. Copy `devices/violet.json` to `devices/<name>.json` and set `arch` (must be `arm64`), `kernel_repo`, `kernel_branch`, `defconfig`, `kernel_version`, `kernel_name`, `clang_version`, and the AnyKernel3 repo and branch.
2. If the kernel's `fs/proc/cmdline.c` needs a SUSFS change that the common patch doesn't apply, add `devices/patches/<name>-cmdline-susfs-port.patch`. `ksu.sh` applies it automatically when `fs/proc/cmdline.c.rej` exists and the file name matches the device.
3. Add `<name>` to the `device_codename` dropdown options in both `bakasu.yml` and `kernelsu.yml`. The dropdown rejects any other value, so this step is required.
4. Run `bakasu.yml` with `device_codename` set to `<name>`. Check the Telegram message and the artifacts.
