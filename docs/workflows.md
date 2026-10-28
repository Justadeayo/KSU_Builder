# Workflows

[← Home](../README.md) · **Workflows** · [Build a SUSFS kernel](build-susfs.md) · [Master script](master-script.md) · [Secrets and outputs](secrets-and-outputs.md) · [Forking](forking.md) · [Troubleshooting](troubleshooting.md) · [History](history.md)

---

Each section lists a workflow's purpose, triggers, inputs and jobs. For the shared steps, see the [master script](master-script.md).

## Contents

- [build.yml](#buildyml-build-xcalibur-xf-susfs-kernel)
- [build-custom.yml](#build-customyml-build-custom-susfs-kernel)
- [automated.yml](#automatedyml-automated-build-for-violet)
- [kernel.yml](#kernelyml-kernel-build-main)
- [kernel_build.yml](#kernel_buildyml-kernel-build-extra)
- [Kernel_&_Manager_build.yml](#kernel__manager_buildyml-kernel--manager-build)
- [build-manager.yml](#build-manageryml-build-manager)
- [release.yml](#releaseyml-release)
- [sync.yml](#syncyml-sync-upstream-updates)

---

## `build.yml`: Build XCalibur-XF SUSFS Kernel

**Purpose:** build violet with SUSFS in `ksu` and `nsu` variants, using the pinned framework in `scripts/` and `devices/`. Sends the flashable zip to Telegram.

- **Triggers:** manual.
- **Inputs:** `create_release` (default `false`) creates a GitHub Release after the build.
- **Jobs:** `build` (one job per variant), then `release` if `create_release` is set.
- Details: [Build a SUSFS kernel](build-susfs.md).

## `build-custom.yml`: Build Custom SUSFS Kernel

**Purpose:** the same build as `build.yml`, with every setting open to override. An empty input keeps the value from `devices/<device>.json`.

- **Triggers:** manual.
- **Inputs:**

| Input | Description | Empty means |
| :--- | :--- | :--- |
| `device_codename` | Device name, matching `devices/<name>.json` | `violet` |
| `kernel_name` | Name used in the zip name | JSON value |
| `kernel_source` | Kernel repository URL | JSON value |
| `kernel_branch` | Kernel branch | JSON value |
| `kernel_version` | `VERSION.PATCHLEVEL` checked in preflight | JSON value |
| `defconfig_name` | Defconfig target | JSON value |
| `clang_version` | Clang version | JSON value |
| `clang_branch` | googlesource branch for that Clang | JSON value |
| `ak3_repo`, `ak3_branch` | AnyKernel3 source | JSON value |
| `telegram_chat_id`, `telegram_bot_token` | Telegram overrides | the repository secrets |
| `create_release` | Create a GitHub Release | `false` |

- **Jobs:** `build` (one job per variant), then `release` if `create_release` is set.

## `automated.yml`: Automated Build for Violet

**Purpose:** a fixed-target build for violet. It builds the kernel and the companion Manager APK in parallel, then sends both to Telegram. `release.yml` calls it.

- **Triggers:** manual, or called by `release.yml`.
- **Defaults:**

| Setting | Value |
| :--- | :--- |
| Clang | `clang-r596125` |
| Kernel repo | `Justadeayo/android_kernel_xiaomi_violet` |
| Branch | `17` |
| Defconfig | `vendor/xcalibur-perf_defconfig` |
| Device | `violet` |
| Kernel name | `XCalibur-XF` |

- **Jobs:**
  1. `build-manager`: calls `build-manager.yml` for the Manager APK.
  2. `Kernel_CI`: clones the kernel, runs the KernelSU `setup.sh`, adds the KSU options to the defconfig, checks they survive `olddefconfig`, compiles, and packages the zip.
  3. `Dispatch`: waits for both jobs, then sends the kernel zip and Manager APK to Telegram.
  4. `Cache_Cleanup`: prunes old ccache entries.

## `kernel.yml`: Kernel Build (main)

**Purpose:** the main standalone build for any kernel source. Builds the kernel and packages an AnyKernel3 zip. Does not build the Manager APK.

- **Triggers:** manual.
- **Inputs:**

| Input | Type | Options or description | Default |
| :--- | :--- | :--- | :--- |
| `kernel_name` | String | Name used in build banners and the zip name | `XCalibur-XF` |
| `clang_version` | Choice | `clang-r596125`, `clang-r416183b` to `clang-r574158`, `clang-stable` | `clang-r596125` |
| `kernel_source` | String | Kernel repository URL | `https://github.com/` |
| `kernel_branch` | String | Kernel branch | required |
| `defconfig_name` | String | Defconfig path under `arch/arm64/configs/` | required |
| `device_codename` | String | Used in the zip name and AnyKernel3 | `violet` |
| `ksu_type` | Choice | `None`, `KernelSU`, `ReSukiSU` | `KernelSU` |
| `BUILD_COMMIT` | String | Note added to the build message | `Synced with upstream changes 💯` |
| `telegram_chat_id`, `telegram_bot_token` | String | Overrides for the secrets | secret fallback |

- **Root choice:** `ksu_type` picks the root setup and the zip label. `ReSukiSU` uses the RKSU branch of the fork.
- **Jobs:** `Kernel_CI` (build, zip, Telegram on success or failure), then `Cache_Cleanup`.

## `kernel_build.yml`: Kernel Build (extra)

**Purpose:** a second standalone build for testing. Same inputs as `kernel.yml`, plus a KernelSU branch.

- **Differences from `kernel.yml`:**
  - `branch` input (default `master`) picks the branch of the KernelSU fork used for `setup.sh`. `ReSukiSU` uses the `sKernelSU` fork.
  - `ReSukiSU` builds also add `CONFIG_KSU_SUSFS=y`.
  - Uploads a `kernel-raw-outputs` artifact with `Image`, `Image.gz`, `dtb` and `dtbo.img`.

## `Kernel_&_Manager_build.yml`: Kernel & Manager Build

**Purpose:** the full custom build. Takes any kernel source, builds the kernel and the Manager APK, and sends both to Telegram.

- **Triggers:** manual.
- **Inputs:** the same as `kernel.yml`. The `clang_version` list also includes `clang-3289846`, `clang-r450784e` and `clang-r475365b`.
- **Jobs:**
  1. `build-manager`: runs only when `ksu_type` is `KernelSU`.
  2. `Kernel_CI`: builds the kernel and uploads `kernel-zip`.
  3. `Dispatch`: sends the Manager APK, the kernel zip and a summary to Telegram.
  4. `Cache_Cleanup`: prunes old ccache entries.

## `build-manager.yml`: Build Manager

**Purpose:** builds the KernelSU Manager APK and the `ksud` binaries. Other workflows call it. It also runs on push to the listed branches.

- **Triggers:** push to `main`, `dev`, `ci`, `test`, `staging`; `workflow_call`; `workflow_dispatch`.
- **Jobs:**
  1. `generate-key`: makes a temporary keystore for PR builds.
  2. `build-ksud`: builds `ksud` for `aarch64-linux-android`, `armv7-linux-androideabi` and `x86_64-linux-android` with NDK r29.
  3. `build-manager`: sets the Manager version, then runs Gradle `assembleRelease`.
  4. `repack-manager`: inserts the `ksud` binaries into the APK and re-signs it.
- **Manager version:** the version name stays at the base tag. The version code is the `KSU_VERSION` number from the fork's `kernel/Makefile`. If that isn't a plain number, the default Gradle version is kept.
- **Outputs:** `manager`, `manager-gradle`, `ksud-*`, `mappings`.

## `release.yml`: Release

**Purpose:** publishes a GitHub Release with the built zips and APKs. Runs when a `v*` tag is pushed, or when started by hand or by another workflow.

- **Inputs:** `is_prerelease` (default `false` for manual runs, `true` when called).
- **Jobs:**
  1. `build`: calls `automated.yml`.
  2. `release`: works out the tag and publishes every `.apk` and `.zip`.
- Manual runs use a version tag such as `v3.3.1-<number>`.
- The Telegram messages come from `automated.yml`, not from this workflow.

## `sync.yml`: Sync Upstream Updates

**Purpose:** keeps `Justadeayo/KernelSU` aligned with upstream every day. It uses a token because it pushes to another repository.

- **Triggers:** daily cron at 00:00 UTC; manual.
- **Input:** `trigger_release` (default `false`) starts `release.yml` on `Justadeayo/KSU_Builder` (`dev`) after a successful sync.
- **Behavior:** compares `master` with upstream. If there are new commits, it resets to upstream and force-pushes, then sends a Telegram notice.
- **Scheduled runs never start a release.**

---

[← Home](../README.md) · [Next: Build a SUSFS kernel →](build-susfs.md)
