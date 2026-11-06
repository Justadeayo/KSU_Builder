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
- [build-env.yml](#build-envyml-build-env-image)
- [build-manager.yml](#build-manageryml-build-manager)
- [release.yml](#releaseyml-release)
- [sync.yml](#syncyml-sync-upstream-updates)

---

## `build.yml`: Build XCalibur-XF SUSFS Kernel

**Purpose:** build violet with SUSFS in `ksu` and `nsu` variants, using the pinned framework in `scripts/` and `devices/`. Sends one start message, then one finish message with the zips once every selected variant succeeds.

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

**Purpose:** a fixed-target build for violet. It builds the kernel and the companion Manager APK in parallel, then sends one start and one finish message. `release.yml` calls it.

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
  1. `sync`: calls `sync.yml` to align `Justadeayo/KernelSU` with upstream. Takes about 15 seconds.
  2. `build-manager`: waits for `sync`, then calls `build-manager.yml` for the Manager APK from the synced source.
  3. `Kernel_CI`: runs in the build image, in parallel with `sync` and `build-manager`. Clones the kernel, runs the KernelSU `setup.sh`, adds the KSU options to the defconfig, checks they survive `olddefconfig`, compiles, and packages the zip.
  4. `Dispatch`: waits for both jobs, then sends the finish message with the kernel zip and Manager APK.
  5. `Cache_Cleanup`: prunes old ccache entries.

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
| `ksu_type` | Choice | `None`, `KernelSU`, `Uni-SU` | `KernelSU` |
| `BUILD_COMMIT` | String | Note added to the build message | `Synced with upstream changes 💯` |
| `telegram_chat_id`, `telegram_bot_token` | String | Overrides for the secrets | secret fallback |

- **Root choice:** `ksu_type` picks the root setup and the zip label. `KernelSU` uses `Justadeayo/KernelSU` (master). `Uni-SU` uses `Justadeayo/sKernelSU` (master), a driver compatible with several managers.
- **Jobs:** `Kernel_CI` (runs in the build image; build and zip), then `Cache_Cleanup`.
- **Clang:** `clang-r596125` comes from the image. Any other `clang_version` is downloaded on the run.

## `kernel_build.yml`: Kernel Build (extra)

**Purpose:** a second standalone build for testing. Same inputs as `kernel.yml`, plus a KernelSU branch.

- **Differences from `kernel.yml`:**
  - `branch` input (default `master`, used when left empty) picks the branch of the driver repo for both the clone and `setup.sh`. `Uni-SU` uses the `sKernelSU` fork; `KernelSU` uses the KernelSU fork.
  - Uploads a `kernel-raw-outputs` artifact with `Image`, `Image.gz`, `dtb` and `dtbo.img`.

## `Kernel_&_Manager_build.yml`: Kernel & Manager Build

**Purpose:** the full custom build. Takes any kernel source, builds the kernel and the Manager APK, and sends one start and one finish message.

- **Triggers:** manual.
- **Inputs:** the same as `kernel.yml`. The `clang_version` list also includes `clang-3289846`, `clang-r450784e` and `clang-r475365b`.
- **Build image:** `Kernel_CI` runs in the build image, as in `kernel.yml`.
- **Jobs:**
  1. `build-manager`: runs only when `ksu_type` is `KernelSU`.
  2. `Kernel_CI`: builds the kernel and uploads `kernel-zip`.
  3. `Dispatch`: sends the finish message with the Manager APK and the kernel zip.
  4. `Cache_Cleanup`: prunes old ccache entries.

## `build-env.yml`: Build Env Image

**Purpose:** builds the build image `ghcr.io/justadeayo/xcalibur-build-env:ubuntu-24.04-clang-r596125` from `docker/build-env/Dockerfile`. The image has the apt build packages (including `gcc-arm-linux-gnueabi`) and `clang-r596125` already extracted at `/opt/toolchains/`. The kernel workflows run inside it, so they skip the apt install and the Clang download.

- **Triggers:** manual, and pushes that change `docker/build-env/**` or this file.
- **Jobs:** `build` (Buildx build and push, with a GitHub Actions layer cache).
- **Changing the image:** edit the Dockerfile and run the workflow. Each kernel job pulls the new image on its next run.
- **Package visibility:** make the package public in its GHCR settings. Private packages on the free plan have only 500 MB of storage.

## `build-manager.yml`: Build Manager

**Purpose:** builds the KernelSU Manager APK and the `ksud` binaries. Other workflows call it. Pushes do not start it.

- **Triggers:** `workflow_call` (from `automated.yml`); `workflow_dispatch`.
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
- This workflow sends no Telegram messages.

## `sync.yml`: Sync Upstream Updates

**Purpose:** keeps `Justadeayo/KernelSU` aligned with upstream, so every automated build uses the latest KernelSU. It uses a token because it pushes to another repository.

- **Triggers:** called by `automated.yml` at the start of each run, or run by hand. The daily schedule was removed.
- **Input:** `trigger_release` (default `false`) starts `release.yml` on `Justadeayo/KSU_Builder` (`dev`) after a successful sync. Calls from `automated.yml` never set it.
- **Behavior:** compares `master` with upstream. If there are new commits, it resets to upstream and force-pushes. It sends no Telegram message.
- **Manual runs start a release only if `trigger_release` is set.**

---

[← Home](../README.md) · [Next: Build a SUSFS kernel →](build-susfs.md)
