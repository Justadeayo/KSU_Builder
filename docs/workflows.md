# Workflows

Every workflow in `.github/workflows/`. Inputs marked "empty = from device JSON" use `devices/<device>.json` when left blank.

Device and Clang inputs are dropdowns. A new device must be added to the `device_codename` options in `bakasu.yml` and `kernelsu.yml`, not only to `devices/`. See [Build a BakaSU SUSFS kernel](build-susfs.md#adding-a-device).

## Contents

- [`bakasu.yml`: BakaSU Kernel Build](#bakasuyml-bakasu-kernel-build)
- [`kernelsu.yml`: KernelSU Kernel Build](#kernelsuyml-kernelsu-kernel-build)
- [`build-manager.yml`: Build Manager](#build-manageryml-build-manager)
- [`build-env.yml`: Build Env Image](#build-envyml-build-env-image)
- [`release.yml`: Release](#releaseyml-release)

---

## `bakasu.yml`: BakaSU Kernel Build

**Trigger:** manual (`workflow_dispatch`).

Builds a device with BakaSU and SUSFS. The `ksu` variant is always built. Set `build_nonksu` to also build the `nsu` variant, which is a non-root build without SUSFS.

| Input | Default | Meaning |
| :--- | :--- | :--- |
| `device_codename` | `violet` | Device dropdown, read from `devices/<name>.json`. Only `violet` is listed today |
| `build_nonksu` | `false` | Also build the `nsu` (non-root) variant |
| `kernel_name` | empty | Kernel name in the zip. Empty = from device JSON |
| `kernel_source` | empty | Kernel repo URL. Empty = from device JSON |
| `kernel_branch` | empty | Kernel branch. Empty = from device JSON |
| `defconfig_name` | empty | Defconfig target. Empty = from device JSON |
| `clang_version` | `default` | Clang dropdown: `default` (from device JSON), `r596125`, `r614150`, `r584948`, `r547379`, `3289846`. Only `r596125` is preinstalled in the build image |
| `create_release` | `false` | Create a GitHub Release after the build |

**Jobs:** config (resolve device), notify start, build, notify finish, notify failed, release (only when `create_release` is set), cache cleanup (prunes old ccache entries after a successful build).

---

## `kernelsu.yml`: KernelSU Kernel Build

**Triggers:** manual (`workflow_dispatch`), and called by `release.yml`.

Builds a device with KernelSU. SUSFS is on by default. Builds with SUSFS get `-SUSFS` added to the kernel name and zip name. `None` builds are not renamed.

| Input | Default | Meaning |
| :--- | :--- | :--- |
| `device_codename` | `violet` | Device dropdown (manual runs). Empty when called, which resolves to `violet` |
| `kernel_name` | empty | Kernel name in the zip. Empty = from device JSON |
| `kernel_source` | empty | Kernel repo URL. Empty = from device JSON |
| `kernel_branch` | empty | Kernel branch. Empty = from device JSON |
| `defconfig_name` | empty | Defconfig target. Empty = from device JSON |
| `clang_version` | `default` | Clang dropdown, same options as `bakasu.yml`. Non-preinstalled versions are downloaded each run |
| `ksu_type` | `KernelSU` | `KernelSU`, or `None` for a non-root build |
| `susfs` | `true` | Apply the SUSFS kernel patches |
| `nomount` | `true` | Integrate NoMount, the built-in VFS driver. Applies only to `KernelSU` builds. NoMount's tag is set in `config.env` |
| `build_manager` | `false` | Also build the Manager APK and attach it to the finish message |

When `build_manager` is true, `build-manager.yml` runs as a called workflow. Its APK is attached to the finish message.

**Jobs:** config, notify start, build-manager (optional), build, notify finish, notify failed, cache cleanup.

---

## `build-manager.yml`: Build Manager

**Triggers:** manual (`workflow_dispatch`), and called by `kernelsu.yml` (which `release.yml` calls with `build_manager: true`).

Builds the KernelSU Manager APK and the `ksud` binaries from the KernelSU source with the patches in `patches/ksu`. The source is fetched from the `dev` branch of this repository. Release-signed builds use the release keystore secrets (see [Secrets and outputs](secrets-and-outputs.md)).

The workflow has no `pull_request` trigger. The temporary PR-signing steps in it therefore never run.

**Artifacts:** `manager` (the APK), `ksud-<target>` (binaries; `armv7` is optional), `manager-gradle` (Gradle outputs), `mappings` (ProGuard mapping files).

---

## `build-env.yml`: Build Env Image

**Triggers:** manual (`workflow_dispatch`), and on pushes that change `docker/build-env/` or this workflow.

Builds and pushes the build image `ghcr.io/justadeayo/xcalibur-build-env:ubuntu-24.04-clang-r596125`. The image holds the apt build packages and `clang-r596125`, so kernel builds don't install them each run.

---

## `release.yml`: Release

**Triggers:** a tag matching `v*`, manual (`workflow_dispatch` with `is_prerelease`), and called.

Builds with `kernelsu.yml` (with `build_manager: true`, so the Manager APK is included), then publishes a GitHub Release.

- Tag pushes use the tag name.
- Manual runs create and push a tag of the form `v3.3.1-<n>`, where `<n>` is the run number plus 3. The `3.3.1` part is typed into the workflow, not read from upstream.
- The release is a prerelease only when `is_prerelease` is set. A manual run defaults to a full release. A called run defaults to a prerelease.
- The release notes are fixed text in the workflow. They include the SUSFS version read from the pinned SUSFS commit, and the NoMount tag from `config.env`.
