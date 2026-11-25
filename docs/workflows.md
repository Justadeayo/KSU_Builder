# Workflows

[← Home](../README.md) · **Workflows** · [Build a SUSFS kernel](build-susfs.md) · [Master script](master-script.md) · [Secrets and outputs](secrets-and-outputs.md) · [Forking](forking.md) · [Troubleshooting](troubleshooting.md) · [History](history.md)

---

Each section lists a workflow's purpose, triggers, inputs and jobs. For the shared steps, see the [master script](master-script.md).

## Contents

- [build.yml](#buildyml-build-susfs-kernel)
- [automated.yml](#automatedyml-automated-build-for-violet)
- [kernel.yml](#kernelyml-kernel-build)
- [build-env.yml](#build-envyml-build-env-image)
- [build-manager.yml](#build-manageryml-build-manager)
- [release.yml](#releaseyml-release)
- [sync.yml](#syncyml-sync-upstream-updates)

---

## `build.yml`: Build SUSFS Kernel

**Purpose:** build a device with SUSFS in `ksu` and `nsu` variants, using the pinned framework in `scripts/` and `devices/`. Sends one start message, then one finish message with the zips once every selected variant succeeds. Every setting can be overridden per run. An empty input keeps the value from `devices/<device>.json`, so an empty form builds violet.

- **Triggers:** manual.
- **Inputs:**

| Input | Description | Empty means |
| :--- | :--- | :--- |
| `build_nonksu` | Also build the non-KSU variant (`nsu`) | off |
| `device_codename` | Device name, matching `devices/<name>.json` | `violet` |
| `kernel_name` | Name used in the zip name | JSON value |
| `kernel_source` | Kernel repository URL | JSON value |
| `kernel_branch` | Kernel branch | JSON value |
| `kernel_version` | `VERSION.PATCHLEVEL` checked in preflight | JSON value |
| `defconfig_name` | Defconfig target | JSON value |
| `clang_version` | Clang version, e.g. `r596125` | JSON value |
| `clang_branch` | googlesource branch for that Clang | JSON value |
| `ak3_repo`, `ak3_branch` | AnyKernel3 source | JSON value |
| `telegram_chat_id`, `telegram_bot_token` | Telegram overrides, used for every message in the run | the repository secrets |
| `create_release` | Create a GitHub Release | `false` |

- **Jobs:**
  1. `config`: resolves the device config once (the JSON with inputs applied, see `scripts/resolve-device.py`) and plans the variants.
  2. `notify_start`: sends the start message.
  3. `build`: one job per variant.
  4. `notify_finish`: sends the finish message with the zips.
  5. `release`: runs only when `create_release` is set.
  6. `Cache_Cleanup`: prunes old ccache entries for that device and branch.
- **Release:** the tag is `xcalibur-xf-<device>-<date>-<run>` and the title is `XCalibur-XF <device> - <date>`. For violet, these match the earlier `build.yml`.
- Details: [Build a SUSFS kernel](build-susfs.md).

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

## `kernel.yml`: Kernel Build

**Purpose:** the standalone kernel build for any kernel source. Builds the kernel and packages an AnyKernel3 zip. Does not build the Manager APK. It also takes the optional raw-image upload, which is off by default.

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
| `ksu_type` | Choice | `None`, `KernelSU` | `KernelSU` |
| `branch` | String | Driver repo branch, for both the clone and `setup.sh` | `master` |
| `BUILD_COMMIT` | String | Note added to the build message | `Synced with upstream changes 💯` |
| `upload_raw_outputs` | Boolean | Also upload `Image`, `Image.gz`, `Image.gz-dtb`, `dtb.img`, `dtb` and `dtbo.img` as a `kernel-raw-outputs` artifact | `false` |
| `telegram_chat_id`, `telegram_bot_token` | String | Overrides for the secrets | secret fallback |

- **Root choice:** `ksu_type` picks the root setup and the zip label. `KernelSU` uses `Justadeayo/KernelSU` on `branch`. `None` skips root setup but still clones the KernelSU repo for its commit message.
- **Jobs:** `notify_start`, `Kernel_CI` (runs in the build image; build and zip), `Dispatch` (sends the finish message with the zip), and `Cache_Cleanup`.
- **Clang:** `clang-r596125` comes from the image. Any other `clang_version` is downloaded on the run.

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
