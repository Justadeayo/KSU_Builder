# KernelSU Build Workflows Guide

```
Designed to compile legacy kernel ( ≥3.8 ) and support KSU manager.
If Unsure how to go about Manager, download from this Repo and updates would be pushed OTA consistently.
But Remember to Fork this Repo to keep your Kernel Zip build up to date.
```

> **⚠️ Important Notice:** These workflows are provided for testing, evaluation, and customization purposes. **Use with caution and at your own risk.** Always verify compatibility with your setup before building. You assume all responsibility for any outcomes.
Make sure you're building a kernel compatible with your device tree, if not keep a backup of working kernel zip or boot.img to be on a safe page while experimenting.
This guide details the automated GitHub Actions workflows in this repository for compiling Android custom kernels and the KernelSU Manager app.
---
## 🛠️ Hardcoded References & Customization Guide
If you fork or adapt this repository for your own kernel/device, **you must replace the following hardcoded values** across the workflow `.yml` files:

| File Path | Hardcoded Field / Value | What to Replace With |
| :--- | :--- | :--- |
| `.github/workflows/Kernel_&_Manager_build.yml` | `Justadeayo/KernelSU` (job call) | `<your-github-username>/<your-repo-name>` |
| `.github/workflows/automated.yml` | `https://github.com/Justadeayo/android_kernel_xiaomi_violet` | Default kernel repo URL for your device |
| `.github/workflows/automated.yml` | `sixteen` / `vendor/violet-perf_defconfig` | Your kernel branch & defconfig path |
| `.github/workflows/automated.yml` | `Justadeayo/KernelSU` & repo URLs | Your repository path & kernel repository URL |
| `.github/workflows/sync.yml` | `gh workflow run release.yml -R Justadeayo/KernelSU` | Replace `Justadeayo/KernelSU` with your repo |
| `.github/workflows/build-manager.yml` | `repository: 'Justadeayo/KernelSU'` | Replace with your KernelSU repository |
| `.github/workflows/build-manager.yml` | `sed -i 's\ | backslashxx/KernelSU\ | Justadeayo/KernelSU\ | g'` | Update patch strings to match your repo |
| `.github/workflows/sync.yml` | `repository: Justadeayo/KernelSU`, `Justadeayo/KSU_Builder` | Replace repository names and `--ref dev` with your setup |

---
## Overview
This repository contains seven primary GitHub Actions workflows:
1. **`build-manager.yml`** — Manager App & `ksud` Binaries
2. **`automated.yml`** — Automated Kernel & Manager CI (Preconfigured target)
3. **`Kernel_&_Manager_build.yml`** — Custom Interactive Matrix Builds
4. **`release.yml`** — Formal Tag & Automated Release Publishing
5. **`sync.yml`** — Upstream Synchronization with Upstream KernelSU
6. **`kernel.yml`** — Kernel Build (main standalone build workflow)
7. **`kernel_build.yml`** — Standalone Kernel Build (extra)
---
## Workflows Breakdown
### 1. `build-manager.yml` — Manager App & ksud Binaries
**Path:** `.github/workflows/build-manager.yml`
Builds the KernelSU Manager APK and compiles native `ksud` binaries for both ARM64 (`aarch64-linux-android`) and ARMv7 (`armv7-linux-androideabi`).
* **Triggers:**
  * Push to branches: `main`, `dev`, `ci`, `test`, `staging`
  * Workflow call (`workflow_call`)
  * Manual dispatch (`workflow_dispatch`)
* **Key Features:**
  * Dynamic PR keystore generation vs. standard dummy release keystore.
  * Native Rust target compilation with Android NDK r29.
  * Automatic repacking of APK with compiled native binaries via `repack_apk.py`.
* **Outputs:**
  * `manager` — Final repacked and signed Manager APK.
  * `ksud-aarch64-linux-android` & `ksud-armv7-linux-androideabi` — Standalone binaries.
  * `mappings` — ProGuard mapping files for debugging release builds.
---

### 2. `automated.yml` — Automated Build (Default Device Target)
**Path:** `.github/workflows/automated.yml`
Fully automated CI pipeline configured for a specific default target (e.g., Xiaomi Redmi Note 7 Pro `violet`).
* **Triggers:**
  * Workflow call (`workflow_call`)
  * Manual dispatch (`workflow_dispatch`)
* **Environment Defaults:**
  ```yaml
  CLANG_VERSION: "clang-r563880c"
  KERNEL_SOURCE: "[https://github.com/Justadeayo/android_kernel_xiaomi_violet](https://github.com/Justadeayo/android_kernel_xiaomi_violet)"
  KERNEL_BRANCH: "sixteen"
  DEFCONFIG_NAME: "vendor/violet-perf_defconfig"
  DEVICE_CODENAME: "violet"
  ```
  * **Build Execution:**
    1. Invokes `build-manager.yml` to compile the companion Manager APK.
    2. Clones the target kernel source and applies `setup.sh` KernelSU patches.
    3. Appends KSU & SuSFS flags (`CONFIG_KSU=y`, `CONFIG_KSU_SUSFS=y`, `CONFIG_KSU_TAMPER_SYSCALL_TABLE=y`) to defconfig.
    4. Compiles using LLVM/Clang toolchain and packages output into AnyKernel3 ZIP.
    5. Sends complete status reports and build artifacts directly to Telegram.
  
---
### 3. `Kernel_&_Manager_build.yml` — Interactive Custom Builds
**Path:** `.github/workflows/Kernel_&_Manager_build.yml`
Interactive, manually triggered workflow allowing users to pass arbitrary kernel sources, branches, defconfigs, root solutions, and Clang toolchains directly via GitHub UI.
* **Triggers:**
  * Manual dispatch (`workflow_dispatch`)
* **Input Options:**

| Input Field | Type | Options / Description | Default |
| :--- | :--- | :--- | :--- |
| `kernel_name` | String | Name of the kernel for build banners | `XCalibur` |
| `clang_version` | Choice | `clang-3289846` through `clang-r574158`, `clang-stable` | *None (Required)* |
| `kernel_source` | String | Target Git repository URL | `https://github.com/` |
| `kernel_branch` | String | Target branch | *None (Required)* |
| `defconfig_name` | String | Relative defconfig path | *None (Required)* |
| `device_codename` | String | Codename for AnyKernel3 branding | `violet` |
| `ksu_type` | Choice | `None`, `KernelSU`, `ReSukiSU-with-susfs` | `KernelSU` |
| `BUILD_COMMIT` | String | Build notes/description | `Synced with upstream changes 💯` |
| `telegram_chat_id` | String | Optional chat ID override | Secret fallback |
| `telegram_bot_token` | String | Optional bot token override | Secret fallback |

* **Advanced Capabilities:**
  * Dynamic `kernel_name` input to customize build headers, zip file name and notification branding.
  * Robust URL encoding using `--data-urlencode` for multi-line Telegram payload stability.
  * Integrated **SuSFS 4.14 patch application** when `ReSukiSU-with-susfs` is selected.
  * Direct delivery of compiled Manager APK and AnyKernel3 flashable ZIP via Telegram.
  * Instant Telegram log forwarding on compilation failure (`error_logs.zip` with 35-line preview).
  
---
### 4. `kernel.yml` — Kernel Build (main)
**Path:** `.github/workflows/kernel.yml`
Main standalone, manually triggered workflow designed to build the kernel image and compile an AnyKernel3 zip without building the KernelSU Manager APK.
* **Triggers:**
  * Manual dispatch (`workflow_dispatch`)
* **Input Options:**

| Input Field | Type | Options / Description | Default |
| :--- | :--- | :--- | :--- |
| `clang_version` | Choice | `clang-r416183b` through `clang-r574158`, `clang-stable` | `clang-r416183b` |
| `kernel_source` | String | Target Git repository URL | `.../android_kernel_xiaomi_violet` |
| `kernel_branch` | String | Target branch | `16.2` |
| `defconfig_name` | String | Relative defconfig path | `vendor/sdmsteppe-perf_defconfig` |
| `device_codename` | String | Codename for AnyKernel3 branding | `violet` |
| `ksu_type` | Choice | `None`, `KernelSU`, `ReSukiSU-with-susfs` | `KernelSU` |
| `BUILD_COMMIT` | String | Build notes/description | `Synced with upstream changes 💯` |
| `telegram_chat_id` | String | Optional chat ID override | Secret fallback |
| `telegram_bot_token` | String | Optional bot token override | Secret fallback |

* **Key Features:**
  * Dual GCC Toolchain integration (`gcc64` & `gcc32`) alongside Clang for legacy cross-compilation support.
  * Automatic fragment config appending (`vendor/debugfs.config`, `vendor/violet.config`) and `-O3` optimization overrides.
  * Direct delivery of the AnyKernel3 flashable ZIP to Telegram upon success.
  * Automatic failure reporting and `error_logs.zip` attachment on compilation failure.
---
### 5. `kernel_build.yml` — Kernel Build (extra)
**Path:** `.github/workflows/kernel_build.yml`
Secondary extra standalone kernel build workflow designed for additional testing setups, alternative matrix setups, or isolated compilation runs without companion manager builds.
* **Triggers:**
  * Manual dispatch (`workflow_dispatch`)
* **Key Features:**
  * Provides a lightweight extra environment for building custom kernel zips.
  * Optimized for quick testing iterations alongside the main `kernel.yml` pipeline.
---
### 6. `release.yml` — Formal Release Publishing
**Path:** `.github/workflows/release.yml`
Orchestrates full production releases whenever a version tag (e.g., `v1.0.0`) is pushed or when called programmatically.
* **Triggers:**
  * Tag Push: `v*`
  * Workflow call (`workflow_call`)
  * Manual dispatch (`workflow_dispatch`)
* **Behavior:**
  1. Triggers `automated.yml` to produce fresh kernel ZIPs and Manager APKs.
  2. Calculates incremental build version tags if run manually (e.g., `v3.3.0-<number>`).
  3. Publishes an official GitHub Release attached with all `.apk` and `.zip` artifacts.
  
---
### 7. `sync.yml` — Upstream Synchronization
**Path:** `.github/workflows/sync.yml`  
Syncs the core KernelSU repository with upstream (`backslashxx/KernelSU`), authenticated via Personal Access Token (`SYNC_PAT`), and dispatches a build run on a separate builder repository (`Justadeayo/KSU_Builder`).
* **Triggers:**
  * Scheduled Cron: Every 15 days (`00:30 UTC`)
  * Manual dispatch (`workflow_dispatch`)
* **Behavior:**
  1. Checks out `Justadeayo/KernelSU` on branch `master` using `${{ secrets.SYNC_PAT }}`.
  2. Compares local `master` against `upstream/master` (or `upstream/main`).
  3. If updates exist, performs a hard reset (`git reset --hard`) to align history and force-pushes to origin `master`.
  4. Formats multi-line commit messages using Python script encoding and sends a Markdown notification via Telegram.
  5. Triggers `release.yml` on the secondary builder repository (`Justadeayo/KSU_Builder`) targeting the `dev` branch via `gh workflow run`.

---

## 🚀 Quick Start Scenarios
### Scenario A: Dispatch a Custom Kernel Build
1. Go to **Actions** → **Kernel & Manager Build**.
2. Click **Run workflow**.
3. Fill in your **Kernel Name**, **Kernel Source Repo**, **Branch**, **Defconfig**, and **Device Codename**.
4. Select your desired **KernelSU Version** (`KernelSU`, `ReSukiSU-with-susfs`, or `None`).
5. Trigger build and monitor progress in Telegram or Actions logs.

### Scenario B: Trigger Automated Manager Build
1. Push any commit targeting `manager/` or `userspace/` on supported branches.
2. Retrieve compiled manager binaries under **Artifacts** → **manager**.

### Scenario C: Create an Official Release Tag
```bash
git tag v3.3.0
git push origin v3.3.0
```
 * release.yml will automatically build the full stack and publish a release.
 
 
### Scenario D: Sync with Upstream & Build
**Use:** `sync.yml`
* Triggered automatically via cron or manually via **Workflow Dispatch**.
* Authenticates using `SYNC_PAT` to sync `Justadeayo/KernelSU` with upstream changes.
* Dispatches `release.yml` on `Justadeayo/KSU_Builder` (`dev` branch) only when new upstream changes are merged.

---

## Build Artifacts & Access

### Where to find built files:
**Releases**
- Only available after a completed successful process, if not use option below

**GitHub UI:**
1. Go to **Actions** tab
2. Select the completed workflow run
3. Scroll to **Artifacts** section
4. Download `manager`, `kernel-zip`, etc.

**Artifact Names:**
- `manager` — Final Manager APK (ready to install)
- `manager-gradle` — Unsigned Gradle APK (intermediate)
- `kernel-zip` — Flashable kernel package
- `ksud-aarch64-linux-android` — ARM64 ksud binary
- `ksud-armv7-linux-androideabi` — ARMv7 ksud binary
- `mappings` — ProGuard obfuscation mappings (release only)

**Telegram**
- Happens if the build is absolutely successful and telegram values were correctly included before build start via secrets or input.
---

## Configuration & Secrets

## 🔐 Required Repository Secrets
Add the following under **Settings** → **Secrets and variables** → **Actions**:

| Secret Name | Description | Example |
| :--- | :--- | :--- |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot Token from [@BotFather](https://t.me/botfather) | `123456789:ABCdefGhIJKlm...` |
| `TELEGRAM_CHAT_ID` | Telegram Chat / Channel ID | `-1001234567890` |
| `SYNC_PAT` | Personal Access Token with repo/workflow permissions for cross-repo synchronization | `ghp_xxxxxxxxxxxx` |

**How to get them:**
1. **Bot Token:** Talk to [@BotFather](https://t.me/botfather) on Telegram
2. **Chat ID:** Use [@userinfobot](https://t.me/userinfobot) or message your bot and check logs

### Keystore (for signing APK)

For **non-PR builds**, the Manager uses dummy keystore credentials (see `build-manager.yml`). 

For **production releases**, you may want to supply your own keystore:
1. Create a keystore file
2. Encode it: `base64 -w 0 my.keystore > encoded.txt`
3. Add as GitHub secret: `KEYSTORE_FILE`
4. Update `build-manager.yml` to use it

---

## Understanding the Build Process

### Manager Build Flow
```
build-manager.yml
  ├─ generate-key (creates PR signing key if needed)
  ├─ build-lkm (compiles kernel module)
  ├─ build-ksuinit (compiles ksuinit binary)
  ├─ build-ksud (compiles ksud for ARM64 + ARMv7)
  ├─ build-manager (Gradle assembleRelease)
  └─ repack-manager (injects binaries, re-signs APK)
```

### Kernel Build Flow
```
1. Clone kernel source
2. Download AOSP Clang toolchain
3. Apply KernelSU patches (setup.sh)
4. Modify defconfig with KSU flags
5. Compile with make -j$(nproc)
6. Copy Image.gz + DTBs
7. Package with AnyKernel3
8. Create GitHub Release
9. Send Telegram notification
```
---

## Troubleshooting

### Build fails with "Cannot find kernel source"
- **Cause:** Kernel repo URL or branch is wrong
- **Fix:** Verify URL and branch exist on GitHub; use HTTPS URLs

### Manager APK is unsigned or won't install
- **Cause:** Running on a PR build without proper keystore
- **Fix:** Use on main branches or supply your own keystore via secrets

### No Telegram notifications
- **Cause:** Bot token or chat ID is invalid/missing
- **Fix:** Verify secrets in **Settings → Secrets and variables → Actions**

### Kernel compilation fails ("olddefconfig" issues)
- **Cause:** Defconfig doesn't exist or symbol dependencies broken
- **Fix:** Verify defconfig path matches your kernel source

### Out of disk space during build
- **Cause:** Clang toolchain + kernel source are large
- **Fix:** Workflow includes SWAP setup; monitor via logs

### APK or Kernel ZIP not in artifacts
- **Cause:** Build failed silently or naming mismatch
- **Fix:** Check job logs in **Actions → [Run] → [Job]** for error messages

### Workflow calls wrong branch
- **Cause:** Hardcoded branch reference instead of dynamic
- **Fix:** Use `${{ github.ref_name }}` instead of hardcoded branch names

---

## Advanced: Customizing Workflows

### Change Telegram notification recipients
Edit the workflow and update hardcoded chat IDs, or pass as secret:

```yaml
TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}
```

### Add a new device preset
1. Duplicate `automated.yml`
2. Rename to e.g. `automated-alioth.yml`
3. Change `DEVICE_CODENAME`, `DEFCONFIG_NAME`, etc.
4. Update `on` trigger or add manual dispatch inputs

### Customize Clang version
In `automated.yml` or manual workflow, change:
```yaml
CLANG_VERSION: "clang-r563880c"  # Change this
```

Available versions: `clang-r563880c`, `clang-r574158`, `clang-r450784e`, `clang-stable`, `and more`

### Skip specific build steps
Add conditions to any step:
```yaml
- name: Some Step
  if: ${{ github.event_name == 'workflow_dispatch' }}
  run: ...
```

### Use dynamic branch references
When calling workflows from other workflows, use:
```yaml
uses: Justadeayo/KernelSU/.github/workflows/build-manager.yml@${{ github.ref_name }}
```

Instead of hardcoding:
```yaml
uses: Justadeayo/KernelSU/.github/workflows/build-manager.yml@test
```

---

## Workflow Status & Monitoring

### View workflow status:
1. Go to **Actions** tab
2. Select workflow (e.g., "Automated Build for Violet")
3. Click the latest run to see real-time logs

### Interpret badge colors:
- 🟢 **Green** — All steps passed
- 🟡 **Yellow** — Running
- 🔴 **Red** — Failed (check logs)

### Check build logs for errors:
1. Click the failed run
2. Click the failed job (e.g., "Kernel_CI")
3. Expand the failed step and read error messages

---

## Performance Tips

### Reduce build time:
- Use `clang-stable` (smallest download)
- Reduce SWAP if you have enough RAM: `swap-size-gb: 8`
- Cache toolchains between runs (currently manual; consider setup-cache action)

### Optimize artifact storage:
- Workflows auto-expire artifacts after 30 days
- Manually delete old runs to save space
- Only upload essential artifacts (disable `mappings` if not needed)

---

## Branch-Specific Notes

This README applies to the **dev** branch (and compatible branches like **test**).

**⚠️ Use with Caution:** While these workflows have been tested and certified as of the current date, they are provided on an **as-is basis**. You assume all responsibility for:
- Testing thoroughly before production use
- Compatibility with your specific hardware and setup
- Any bricked devices or failed builds
- Data loss or other adverse outcomes

The workflows here are provided for testing and evaluation purposes. Always verify compatibility with your setup before using in production.

**Branch comparison:**
- **main:** ${{To_be_Updated}}
- **test:** dev workflows (testing phase, use with caution)
- **dev:** Extended custom workflows (tested and certified)

---

## Support & Contributing

**Issues or improvements?**
- Report via GitHub Issues with workflow name and error logs
- Include device info and kernel source details
- You can also report any issues or feedback directly to my GitHub DM using the following format:
  ```text
  [Workflow Issue / Feedback]
  Workflow Name: <e.g., Kernel_&_Manager_build.yml>
  Device / Codename: <e.g., Xiaomi Redmi Note 7 Pro / violet>
  Kernel Source & Branch: <e.g., [https://github.com/](https://github.com/)... / sixteen>
  Error Description / Logs: <Brief attached details logs or>
  ```
- Note: Support is provided on best-effort basis
**Want to add a new workflow?**
- Follow the naming convention: `workflow-purpose.yml`
- Document triggers, inputs, and outputs
- Test on a non-main branch first
- Ensure dynamic references where applicable
---
## Disclaimer
By using these workflows, you acknowledge:
- ✅ You understand the experimental nature of this branch
- ✅ You will test thoroughly before production use
- ✅ You assume all risks and responsibility for outcomes
- ✅ The authors and maintainers are not liable for any damages
- ✅ You have read and accepted the `LICENSE`
For more information, see `LICENSE` in the repository root.
---
---
## 📑 Version History

| Version | Date | Notes | Branch |
| :--- | :--- | :--- | :--- |
| **1.6** | 2026-09-08 | Refactor workflows to work from secondary repository, implemented the use of PAT to communicate with KernelSU Repo `(for sync.yml)`, dynamic naming of flashable zip file | `dev` |
| **1.5** | 2026-09-07 | Updated workflow count to 7, designated `kernel.yml` as main standalone, added `kernel_build.yml` (extra), updated `Kernel_&_Manager_build.yml` with dynamic `kernel_name` and Telegram `--data-urlencode` payload fixes. | `dev` |
| **1.4** | 2026-09-05 | Added kernel.yml for standalone kernel builds & supported `clang-r416183b` for faster build | `dev` |
| **1.3** | 2026-09-01 | Extended parameter customization, SuSFS 4.14 patch automation, and hardcode mapping guide | `dev` |
| **1.2** | 2026-08-19 | Automated upstream synchronization and scheduled release triggers | `dev`, `test` |
| **1.1** | 2026-07-26 | Dynamic workflow references and interactive dispatch parameters | `dev`, `test` |
| **1.0** | 2026-07-20 | Initial automated kernel & manager build release | `test` |

---
**Last Updated:** 2026-09-08  
**Primary Branches:** dev  
**Status:** ⚠️ Development Phase