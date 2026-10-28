# KSU_Builder

GitHub Actions workflows for building Android kernels (with KernelSU or
SUSFS) and the KernelSU Manager app. The current target is the Xiaomi Redmi
Note 7 Pro (`violet`) with the XCalibur-XF kernel.

> **Use with caution and at your own risk.** These workflows are for testing,
> evaluation and customization. Check compatibility with your device before
> flashing anything. Keep a working boot image or kernel zip somewhere safe.
> See `LICENSE` for the full terms.

---

## Contents

1. [Workflows at a glance](#workflows-at-a-glance)
2. [The master script](#the-master-script)
3. [Workflow reference](#workflow-reference)
4. [Build a SUSFS kernel (`build.yml`)](#build-a-susfs-kernel-buildyml)
5. [Secrets](#secrets)
6. [Where the outputs go](#where-the-outputs-go)
7. [Hardcoded values to change when forking](#hardcoded-values-to-change-when-forking)
8. [Troubleshooting](#troubleshooting)
9. [Credits, license and version history](#credits-license-and-version-history)

---

## Workflows at a glance

| Workflow | Trigger | Purpose | Uses master script |
| :--- | :--- | :--- | :--- |
| `build.yml` (Build XCalibur-XF SUSFS Kernel) | Manual | Build the violet SUSFS kernel in `ksu` and `nsu` variants, using the framework in `scripts/` and `devices/` | deps, Telegram |
| `automated.yml` (Automated Build for Violet) | Manual, or called by `release.yml` | Fixed-target kernel and Manager build for violet, with Telegram delivery | deps, clang, Telegram, AnyKernel3 |
| `kernel.yml` (Kernel Build (main)) | Manual | Standalone kernel build with custom source, branch, defconfig and root choice. No Manager APK | deps, clang, Telegram, AnyKernel3 |
| `kernel_build.yml` (Kernel Build (extra)) | Manual | Same as `kernel.yml`, plus a KernelSU branch choice and a raw-outputs artifact for testing | deps, clang, Telegram, AnyKernel3 |
| `Kernel_&_Manager_build.yml` (Kernel & Manager Build) | Manual | Full custom build: kernel plus the Manager APK, sent to Telegram together | deps, clang, Telegram, AnyKernel3 |
| `build-manager.yml` (Build Manager) | Push to `main`, `dev`, `ci`, `test`, `staging`; called; manual | Builds the KernelSU Manager APK and the `ksud` binaries | none (self-contained) |
| `release.yml` (Release) | Tag `v*`; manual; called | Publishes a GitHub Release from the automated build | none (calls `automated.yml`) |
| `sync.yml` (Sync Upstream Updates) | Daily at 00:00 UTC; manual | Keeps the KernelSU fork aligned with upstream | none |

"Uses master script" lists the shared steps each workflow takes from
`scripts/master.sh`. Steps that are unique to a workflow stay in that workflow.

---

## The master script

`scripts/master.sh` holds the steps that every build workflow used to repeat:
installing dependencies, fetching Clang, sending Telegram messages and
packaging the AnyKernel3 zip. Workflows call it with one line instead of
carrying their own copy.

```bash
bash scripts/master.sh deps
bash scripts/master.sh clang <clang-version> [dest-dir]
bash scripts/master.sh tg-msg "<markdown text>"
bash scripts/master.sh tg-doc <file> "<markdown caption>"
bash scripts/master.sh anykernel <boot-dir> <kernel-name> <device> <label> <clang-bin-dir>
bash scripts/master.sh ksu-setup <kernel-dir> <ksu-type> <defconfig> <setup-url>
bash scripts/master.sh compile <clang-version> <defconfig-target> <kernel-dir> <log-file>
bash scripts/master.sh fail-report <log-file> <device> <label> <start-epoch>
bash scripts/master.sh prune-ccache <cache-key>
bash scripts/master.sh help
```

| Command | What it does |
| :--- | :--- |
| `deps` | Removes stale apt sources, then installs the build packages (one list for every workflow). |
| `clang` | Downloads and extracts a Clang version into `toolchains/<version>`. It tries the `main-kernel`, `android-14`, `android16-qpr2` and `main` googlesource refs in turn. `clang-r416183b` is cloned from LineageOS. Fails if `bin/clang` is missing after the download. Skips the download if Clang is already there. |
| `tg-msg` | Sends a Markdown message to Telegram. |
| `tg-doc` | Sends a file to Telegram with a Markdown caption. If the file is missing, it sends the caption as a message. |
| `ksu-setup` | Runs a KernelSU or ReSukiSU `setup.sh` in the kernel tree, rewrites the fork owner to Justadeayo, and appends the root options to the defconfig (`ReSukiSU` also gets `CONFIG_KSU_SUSFS=y`). `None` does nothing. The caller gives the `setup.sh` URL, so each workflow still chooses its own fork and branch. |
| `compile` | Exports the Clang and ccache environment, runs `make` and `olddefconfig`, and builds with the log written to the given file. With `REQUIRE_KSU_TAMPER=true` it fails when the final `.config` lost `CONFIG_KSU_TAMPER_SYSCALL_TABLE`. |
| `fail-report` | Sends the failure message with the last 35 log lines zipped. Falls back to a plain message when there is no log. Duration comes from the start epoch. |
| `prune-ccache` | Deletes all but the newest ccache entry for a key. |
| `anykernel` | Copies the kernel image and DTB files from `boot-dir` into an AnyKernel3 folder, fills in the device, Clang version and build date, and zips the result. Prints the zip name on stdout. The `label` sets the zip name. `None`, `NoKSU` and `nsu` turn off `ksu_supported`. Any other label turns it on. |

**Environment**

| Variable | Used by | Default |
| :--- | :--- | :--- |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | `tg-msg`, `tg-doc` | none. If either is missing, Telegram steps are skipped and the build continues. |
| `AK3_REPO`, `AK3_BRANCH` | `anykernel` | `https://github.com/Justadeayo/AnyKernel3.git`, `master` |

**Rules**

- Telegram failures never fail a build.
- `common.sh` provides `log`, `warn` and `die`. The master script sources it.
- Logs go to stderr. The only thing on stdout is what a command is meant to return, such as the zip name from `anykernel`.
- Run `help` to see the commands. An unknown command exits with an error.

**Where it is called**

- `automated.yml`, `kernel.yml`, `kernel_build.yml`: `deps`, `clang`, `ksu-setup`, `compile`, `fail-report`, `prune-ccache`, `tg-msg`, `tg-doc`, `anykernel`
- `Kernel_&_Manager_build.yml`: `deps`, `clang`, `compile`, `fail-report`, `prune-ccache`, `tg-msg`, `tg-doc`, `anykernel`
- `build.yml`: `deps`, `tg-msg`, `tg-doc`

The `scripts/env.sh`, `variant.sh`, `ksu.sh`, `compile.sh` and `common.sh` files are the framework used by `build.yml`. They stay separate because they handle the SUSFS build and the device JSON.

**Still inline:** the Manager APK delivery in `Dispatch` (`automated.yml`, `Kernel_&_Manager_build.yml`), the `build-manager.yml` steps, and the job-level setup each kernel workflow has (checkout, swap, ccache, source clone). The last group needs GitHub Actions' own steps or a composite action, so it can't move into a shell script.

---

## Workflow reference

### `build.yml`: Build XCalibur-XF SUSFS Kernel

**Purpose:** build the violet kernel with SUSFS, in `ksu` and `nsu` variants, using the pinned framework in `scripts/` and `devices/`. Send the flashable zip to Telegram.

See [Build a SUSFS kernel](#build-a-susfs-kernel-buildyml) for details.

### `automated.yml`: Automated Build for Violet

**Purpose:** a fixed-target build for violet. It builds the kernel and the companion Manager APK in parallel, then sends both to Telegram. It is the workflow `release.yml` calls.

- **Triggers:** manual, or called by `release.yml`.
- **Defaults:** Clang `clang-r596125`, kernel repo `Justadeayo/android_kernel_xiaomi_violet`, branch `17`, defconfig `vendor/xcalibur-perf_defconfig`, device `violet`, kernel name `XCalibur-XF`.
- **Jobs:**
  1. `build-manager`: calls `build-manager.yml` for the Manager APK.
  2. `Kernel_CI`: clones the kernel, runs KernelSU `setup.sh`, adds the KSU options to the defconfig, checks they survive `olddefconfig`, compiles, and packages the zip.
  3. `Dispatch`: waits for both jobs, then sends the kernel zip and Manager APK to Telegram.
  4. `Cache_Cleanup`: prunes old ccache entries.

### `kernel.yml`: Kernel Build (main)

**Purpose:** the main standalone build for any kernel source you give it. It builds the kernel and packages an AnyKernel3 zip. It does not build the Manager APK.

- **Triggers:** manual.
- **Inputs:** see the table below.
- **Root choice:** `ksu_type` is `None`, `KernelSU` or `ReSukiSU`. The root setup and the zip label follow this choice.

| Input | Type | Options or description | Default |
| :--- | :--- | :--- | :--- |
| `kernel_name` | String | Name used in build banners and the zip name | `XCalibur-XF` |
| `clang_version` | Choice | `clang-r596125`, `clang-r416183b` to `clang-r574158`, `clang-stable` | `clang-r596125` |
| `kernel_source` | String | Kernel repository URL | `https://github.com/` |
| `kernel_branch` | String | Kernel branch | required |
| `defconfig_name` | String | Defconfig path under `arch/arm64/configs/` | required |
| `device_codename` | String | Codename used in the zip name and AnyKernel3 | `violet` |
| `ksu_type` | Choice | `None`, `KernelSU`, `ReSukiSU` | `KernelSU` |
| `BUILD_COMMIT` | String | Note added to the build message | `Synced with upstream changes 💯` |
| `telegram_chat_id`, `telegram_bot_token` | String | Overrides for the secrets | secret fallback |

- **Jobs:** `Kernel_CI` (build and zip, Telegram on success or failure), then `Cache_Cleanup`.

### `kernel_build.yml`: Kernel Build (extra)

**Purpose:** a second standalone build for testing. It has the same inputs as `kernel.yml`, plus a KernelSU branch.

- **Differences from `kernel.yml`:**
  - `branch` input (default `master`) picks the branch of the KernelSU fork used for `setup.sh` and the metadata.
  - `ReSukiSU` builds add `CONFIG_KSU_SUSFS=y` to the defconfig.
  - Uploads a `kernel-raw-outputs` artifact with `Image`, `Image.gz`, `dtb` and `dtbo.img`.

### `Kernel_&_Manager_build.yml`: Kernel & Manager Build

**Purpose:** the full custom build. It takes any kernel source, builds the kernel and the Manager APK, and sends both to Telegram.

- **Triggers:** manual.
- **Inputs:** the same as `kernel.yml`, with a fixed `clang_version` list that also includes `clang-3289846`, `clang-r450784e` and `clang-r475365b`.
- **Jobs:**
  1. `build-manager`: runs only when `ksu_type` is `KernelSU`.
  2. `Kernel_CI`: builds the kernel and uploads `kernel-zip`.
  3. `Dispatch`: sends the Manager APK, the kernel zip and a summary to Telegram.
  4. `Cache_Cleanup`: prunes old ccache entries.

### `build-manager.yml`: Build Manager

**Purpose:** builds the KernelSU Manager APK and the `ksud` binaries. Other workflows call it. It also runs on push to the listed branches.

- **Triggers:** push to `main`, `dev`, `ci`, `test`, `staging`; `workflow_call`; `workflow_dispatch`.
- **Jobs:**
  1. `generate-key`: makes a temporary keystore for PR builds.
  2. `build-ksud`: builds `ksud` for `aarch64-linux-android`, `armv7-linux-androideabi` and `x86_64-linux-android` with NDK r29.
  3. `build-manager`: sets the Manager version, then runs Gradle `assembleRelease`.
  4. `repack-manager`: inserts the `ksud` binaries into the APK and re-signs it.
- **Manager version:** the version name stays at the base tag. The version code is the `KSU_VERSION` number from the fork's `kernel/Makefile`. If that isn't a plain number, the default Gradle version is kept.
- **Outputs:** `manager`, `manager-gradle`, `ksud-*`, `mappings`.

### `release.yml`: Release

**Purpose:** publishes a GitHub Release with the built zips and APKs. It runs when a `v*` tag is pushed, or when started by hand or by another workflow.

- **Inputs:** `is_prerelease` (default `false` for manual runs, `true` when called).
- **Jobs:**
  1. `build`: calls `automated.yml`.
  2. `release`: works out the tag and publishes the release with every `.apk` and `.zip`.
- Manual runs use a version tag such as `v3.3.1-<number>`.
- The Telegram messages come from `automated.yml`, not from this workflow.

### `sync.yml`: Sync Upstream Updates

**Purpose:** keeps `Justadeayo/KernelSU` aligned with upstream every day. It uses a token because it pushes to another repository.

- **Triggers:** daily cron at 00:00 UTC; manual.
- **Input:** `trigger_release` (default `false`) starts `release.yml` on `Justadeayo/KSU_Builder` (`dev`) after a successful sync.
- **Behavior:** compares `master` with upstream. If there are new commits, it resets to upstream and force-pushes. It then sends a Telegram notice.
- **Scheduled runs never start a release.**

---

## Build a SUSFS kernel (`build.yml`)

`build.yml` builds violet with SUSFS. It is the one workflow that uses the
framework in `scripts/`, `devices/` and `config.env`.

### How to run it

1. Go to **Actions** → **Build XCalibur-XF SUSFS Kernel (violet)**.
2. Click **Run workflow**.
3. Set **create_release** if you want a GitHub Release. Leave it `false` otherwise.

### What it does

- **Matrix:** two jobs, one for `ksu` and one for `nsu`. `fail-fast` is off, so one failing variant doesn't stop the other.
- **Steps:**
  1. Installs dependencies (`master.sh deps`).
  2. Clones the kernel source from `devices/violet.json`.
  3. Restores the Clang and ccache caches.
  4. Runs `env.sh`, `variant.sh` and `compile.sh`.
  5. Uploads the zip and debug artifacts.
  6. Sends the zip to Telegram on success, or the last 35 log lines on failure (`master.sh tg-doc` / `tg-msg`).
- **Release job** (only if `create_release` is `true`): gathers every `xcalibur-xf-*` artifact and publishes one release. Release notes show the BakaSU and SuSFS versions from the `ksu` build.

### Variants

| Variant | What it is |
| :--- | :--- |
| `ksu` | BakaSU and SuSFS, applied by `scripts/ksu.sh`. |
| `nsu` | Stock kernel with no KernelSU. |

### Outputs

| Artifact | Contents |
| :--- | :--- |
| `xcalibur-xf-violet-<variant>` | Flashable zip |
| `debug-violet-<variant>` | Build log and final `.config` |
| `xcalibur-xf-violet-ksu-versions` | BakaSU and SuSFS versions (`ksu` only) |
| `xcalibur-xf-violet-<variant>-rejects` | Patch reject files (failed builds only) |

### Framework layout

```
config.env            BakaSU and SuSFS repo URLs and pinned commits
devices/<name>.json   Device config: kernel repo and branch, defconfig, kernel version,
                      Clang version and branch, AnyKernel3 repo and branch, variants
devices/patches/      Device-specific fixes applied during ksu builds
scripts/master.sh     Shared steps for every workflow (see The master script)
scripts/common.sh     Logging, JSON reader, retrying fetch, kernel version check
scripts/env.sh        Fetches the pinned Clang and exports the build environment
scripts/variant.sh    Runs ksu.sh for the ksu variant; nothing extra for nsu
scripts/ksu.sh        Clones BakaSU and SuSFS at their pins, applies SuSFS,
                      fixes exports, writes the config fragment
scripts/compile.sh    Builds the kernel, merges the fragment, packages the zip
```

### Adding a device

1. Create `devices/<name>.json` with the same fields as `devices/violet.json`. The top-level key must match the file name.
2. Set `kernel_version` to the `VERSION.PATCHLEVEL` in the kernel's `Makefile`. The preflight step fails the build if they differ.
3. Set `clang_branch` to the googlesource branch that clang version was published under. `env.sh` won't guess it.
4. If the SuSFS patch leaves a reject in a file your kernel changes differently, add a port patch under `devices/patches/<name>-<file>.patch` and apply it in `ksu.sh`, as done for violet's `fs/proc/cmdline.c`.
5. `build.yml` is hardcoded to violet. For a second device, copy the workflow and change `devices/violet.json` to your device's file name in the `Read device config` and `Build` steps.

---

## Secrets

Add these under **Settings** → **Secrets and variables** → **Actions**.

| Secret | Used by | Description |
| :--- | :--- | :--- |
| `TELEGRAM_BOT_TOKEN` | Telegram steps | Bot token from [@BotFather](https://t.me/botfather) |
| `TELEGRAM_CHAT_ID` | Telegram steps | Chat or channel ID, e.g. `-1001234567890` |
| `SYNC_PAT` | `sync.yml` | Personal access token with repo and workflow permissions |

To get the chat ID, message your bot and check the update log, or use [@userinfobot](https://t.me/userinfobot).

If the Telegram secrets aren't set, the Telegram steps are skipped and the build still runs.

### Keystore for release-signed Manager builds

Non-PR builds use the dummy keystore in `build-manager.yml`. To sign with your own key:

1. Create a keystore file.
2. Encode it: `base64 -w 0 my.keystore > encoded.txt`.
3. Add it as a secret, for example `KEYSTORE_FILE`.
4. Update `build-manager.yml` to use it.

---

## Where the outputs go

**Releases:** only created by `release.yml`, or by `create_release` in `build.yml`.

**Actions artifacts:** open the run, scroll to **Artifacts**.

| Artifact | Produced by |
| :--- | :--- |
| `manager`, `manager-gradle`, `ksud-*`, `mappings` | `build-manager.yml` |
| `kernel-zip` | `automated.yml`, `kernel.yml`, `kernel_build.yml`, `Kernel_&_Manager_build.yml` |
| `kernel-raw-outputs` | `kernel_build.yml` |
| `xcalibur-xf-violet-<variant>` | `build.yml` |
| `debug-violet-<variant>` | `build.yml` |
| `xcalibur-xf-violet-ksu-versions` | `build.yml` (`ksu` only) |
| `xcalibur-xf-violet-<variant>-rejects` | `build.yml` (failed builds only) |

**Telegram:** the kernel zip is sent on success. A failed build sends the last 35 log lines. `Dispatch` also sends the Manager APK in the two workflows that build it.

---

## Hardcoded values to change when forking

If you fork this repository for your own kernel or device, replace these values.

| File | Value | Replace with |
| :--- | :--- | :--- |
| `.github/workflows/automated.yml`, `Kernel_&_Manager_build.yml` | `Justadeayo/KSU_Builder/.github/workflows/build-manager.yml@dev` | Your username, repo and branch |
| `.github/workflows/automated.yml` | `KERNEL_SOURCE`, `KERNEL_BRANCH`, `DEFCONFIG_NAME` | Your device's kernel repo, branch and defconfig |
| `.github/workflows/kernel.yml`, `kernel_build.yml` | `Justadeayo/KernelSU`, `Justadeayo/sKernelSU`, `Justadeayo/AnyKernel3` | Your forks |
| `scripts/master.sh` | `AK3_REPO`, `AK3_BRANCH` defaults | Your AnyKernel3 fork |
| `.github/workflows/release.yml` | Tag prefix and git identity | Your tag prefix and git identity |
| `.github/workflows/sync.yml` | `Justadeayo/KernelSU`, `Justadeayo/KSU_Builder` | Your repos |
| `.github/workflows/build-manager.yml` | `Justadeayo/KernelSU` checkouts and the repository patch | Your KernelSU repo |
| `devices/violet.json` | `kernel_repo`, `kernel_branch`, `defconfig`, `clang_version`, `clang_branch`, `ak3_repo` | Your device's values |
| `config.env` | `KSU_REPO_URL` and `KSU_REPO_PIN`, `SUSFS_REPO_URL` and `SUSFS_REPO_PIN` | Your pins. Update them only after testing. |

---

## Troubleshooting

### "Cannot find kernel source"
The kernel repo URL or branch is wrong. Check that both exist and use an HTTPS URL.

### Kernel compile fails in `olddefconfig`
The defconfig path is wrong, or a symbol dependency is broken. Check the path under `arch/arm64/configs/`.

### Out of disk space
The Clang toolchain and kernel source are large. The workflows set up swap space. Check the swap step in the log.

### Telegram messages don't arrive
The bot token or chat ID is missing or wrong. Check the secrets. A missing secret skips the Telegram steps without failing the build.

### Clang downloads on every run
GitHub caches are visible only to the branch that created them, or to the default branch. A new `clang_version` creates a new cache, so the first run after a change always downloads. Run from the same branch each time.

### Manager APK missing in Telegram
`build-manager` failed or was skipped (for example, `ksu_type` is `None`). Check the `Dispatch` job for the "No manager APK found" warning, then check the `build-manager` result.

### Artifact or zip missing
Check the job log for errors. Zip names follow `<kernel-name>_<device>_<label>_<timestamp>`. Make sure the artifact name you're looking for matches.

### `build.yml`: real SuSFS rejects
The SuSFS patch doesn't match a kernel file. Download the `-rejects` artifact and find the `.rej` file. Add a port patch under `devices/patches/` and apply it in `ksu.sh`.

### `build.yml`: BakaSU is not at the pinned commit
`setup.sh` couldn't check out `KSU_REPO_PIN` and fell back to the default branch. Confirm the pin exists in the BakaSU repository.

### `build.yml`: `kernel_version mismatch`
`kernel_version` in `devices/<name>.json` doesn't match the kernel's `Makefile`. Update the JSON.

### `master.sh clang` can't download a version
None of the googlesource refs has that version. Check the name on [googlesource](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86) and add its ref to `cmd_clang` if it lives somewhere new.

### A workflow calls the wrong branch
Use `${{ github.ref_name }}` instead of a hardcoded branch name when calling a reusable workflow.

---

## Credits, license and version history

### Credits

- [yureixen](https://github.com/yureixen/zincore-forge) for Zincore Forge, whose framework `build.yml` is based on. Zincore Forge is licensed under GPL-2.0.

### License

- The license in `LICENSE` covers the files written for this repository.
- Files copied or adapted from [Zincore Forge](https://github.com/yureixen/zincore-forge) are licensed under **GPL-2.0**. Each has a header comment, and the GPL-2.0 text is in `LICENSE-GPL-2.0`. These are `scripts/common.sh`, `compile.sh`, `env.sh`, `ksu.sh`, `variant.sh`, `config.env` and `.github/workflows/build.yml`.

### Support

Report problems through GitHub Issues. Include the workflow name, the device, the kernel source and branch, and the error log. Support is best-effort.

### Version history

| Version | Date | Notes | Branch |
| :--- | :--- | :--- | :--- |
| **2.4** | 2026-10-28 | Added `scripts/master.sh`, which holds the shared dependency, Clang, Telegram, AnyKernel3, KernelSU setup, compile, failure-report and ccache-prune steps. Telegram sends retry as plain text when Markdown is rejected. Wired `automated.yml`, `kernel.yml`, `kernel_build.yml`, `Kernel_&_Manager_build.yml` and `build.yml` to it. `build.yml` is now violet-only with a manual trigger, a `create_release` input and Telegram delivery. Rewrote this README around each workflow's purpose. | `dev` |
| **2.3** | 2026-10-28 | Added `build.yml` (Build SUSFS Kernel) with `devices/*.json`, pinned `config.env` and the `scripts/` framework. Violet targets Justadeayo/android_kernel_xiaomi_violet branch `17` with a SuSFS cmdline port patch. | `dev` |
| **2.2** | 2026-10-18 | Base release tag and version references bumped from `v3.3.0` to `v3.3.1` in `release.yml`, `build-manager.yml` and this README. | `dev` |
| **2.1** | 2026-10-06 | Shared Clang cache and ccache compiler check across kernel workflows. Telegram delivery moved into a `Dispatch` job so the Manager APK is always attached. `release.yml` no longer sends a Telegram success message. Manager version code comes from the fork's Makefile. Added `clang-r596125` to `Kernel_&_Manager_build.yml`. | `dev` |
| **2.0** | 2026-09-19 | `kernel_build.yml` became a dynamic version of `kernel.yml`, with a KernelSU branch input. Build Manager steps matched to upstream. | `dev` |
| **1.9** | 2026-09-13 | `sync.yml` moved to a daily cron. `release.yml` job renamed to `build`. External calls default to prerelease. | `dev` |
| **1.8** | 2026-09-11 | Removed SuSFS patch URL dependencies from the active kernel workflows. | `dev` |
| **1.7** | 2026-09-11 | Release is a prerelease on workflow call and a full release on dispatch. | `dev` |
| **1.6** | 2026-09-08 | Workflows work from a secondary repository. PAT used for `sync.yml`. Flashable zip name is dynamic. | `dev` |
| **1.5** | 2026-09-07 | Seven workflows. `kernel.yml` is the main standalone build. Added `kernel_build.yml`. Dynamic `kernel_name` in `Kernel_&_Manager_build.yml`. Telegram payload fixes. | `dev` |
| **1.4** | 2026-09-05 | Added `kernel.yml` and `clang-r416183b` support. | `dev` |
| **1.3** | 2026-09-01 | Parameter customization, SuSFS 4.14 patch automation, hardcoded-value guide. | `dev` |
| **1.2** | 2026-08-19 | Automated upstream sync and scheduled release triggers. | `dev`, `test` |
| **1.1** | 2026-07-26 | Dynamic workflow references and interactive dispatch parameters. | `dev`, `test` |
| **1.0** | 2026-07-20 | Initial automated kernel and Manager build release. | `test` |

---

**Last updated:** 2026-10-28
**Primary branch:** `dev`
