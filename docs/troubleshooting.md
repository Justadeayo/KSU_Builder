# Troubleshooting

[← Home](../README.md) · [Workflows](workflows.md) · [Build a BakaSU SUSFS kernel](build-susfs.md) · [Master script](master-script.md) · [Secrets and outputs](secrets-and-outputs.md) · [Forking](forking.md) · **Troubleshooting** · [History](history.md)

---

## Contents

- [General](#general)
- [KernelSU and NoMount (`kernelsu.yml`)](#kernelsu-and-nomount-kernelsuyml)
- [BakaSU build framework (`bakasu.yml`)](#bakasu-build-framework-bakasuyml)
- [Workflow calls the wrong branch](#workflow-calls-the-wrong-branch)

## General

### "Cannot find kernel source"
The kernel repo URL or branch is wrong. Check that both exist and use an HTTPS URL. If the value came from `devices/<name>.json`, check the file, or fill in `kernel_source` and `kernel_branch` on the run to override it.

### Kernel compile fails in `olddefconfig`
The defconfig path is wrong, or a symbol dependency is broken. Check the path under `arch/arm64/configs/`. `defconfig_name` is relative to that folder, for example `vendor/xcalibur-perf_defconfig`.

### Out of disk space
The Clang toolchain and kernel source are large. The workflows set up swap space. Check the swap step in the log. In `bakasu.yml` the swap step is allowed to fail, so a missing swap line in the log doesn't stop the build by itself.

### Telegram messages don't arrive
- The bot token or chat ID is missing or wrong. Check the secrets.
- `scripts/notify.sh` sends nothing when either variable is unset, and the build still runs.
- If Telegram rejects the Markdown, `notify.sh` resends the message as plain text. If the plain send also fails, the chat ID or token is the likely cause.
- If the finish message says some files failed to upload, the build still succeeded. The files are in the workflow artifacts. The finish step exits with an error so the failed upload shows in the run.

### Build image pull fails
The build job stops before any step runs if it can't pull `ghcr.io/justadeayo/xcalibur-build-env`. Re-run the job, which is usually enough after a network drop. If it keeps failing, check that the package exists and is public, and that the *Build Env Image* workflow has run at least once. On a fork, see [Forking](forking.md) for the image name.

### Clang downloads on every run
Only the Clang version preinstalled in the build image (`clang-r596125`) is free. Any other `clang_version` is downloaded from AOSP googlesource on each run, because toolchains are not cached. The kernel's ccache is keyed by device and branch. Changing the Clang version changes the compiler check, so ccache misses until it refills.

### Manager APK missing in the finish message
The Manager APK is attached only when `build_manager` is `true`. Check that input on the run. Also check that *Build Manager* succeeded: if its job failed, the APK isn't in the finish message. `release.yml` always sets `build_manager: true`.

### Artifact or zip missing
Check the job log for the zip name, then look for the artifact with the same name. Artifact names are listed in [Secrets and outputs](secrets-and-outputs.md#where-the-outputs-go).

### `master.sh clang` can't download a version
None of the googlesource refs has that version. Check the name on [googlesource](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86). Refs are tried in order from two arrays in `scripts/master.sh`: `CLANG_REF` (per-version refs) and `DEFAULT_REFS` (the fallback chain). Add the ref to whichever fits. `clang-r416183b` is a special case and is cloned from LineageOS.

## KernelSU and NoMount (`kernelsu.yml`)

### NoMount setup fails
`scripts/nomount.sh` stops the build if the `fs/nomount` symlink, its line in `fs/Makefile`, or its Kconfig line is missing afterwards. Check that `NOMOUNT_TAG` in `config.env` names a tag that exists in the NoMount repo. To build without NoMount, turn off the `nomount` input on the run, or set `NOMOUNT_TAG` empty in `config.env` to disable it everywhere.

### `NoMount is integrated but CONFIG_NOMOUNT=y is missing`
This comes from `compile.sh`, used by the BakaSU path. The NoMount config option was dropped by `olddefconfig`. Check that the config fragment still has `-e CONFIG_NOMOUNT`.

### `CONFIG_KSU_TAMPER_SYSCALL_TABLE is not enabled in the final .config`
The KernelSU build needs this option for root to work, and the compile step fails when it is missing. Check the `ksu-setup` step, which appends it to the defconfig, and whether a later step overwrote the file.

## BakaSU build framework (`bakasu.yml`)

### Real SuSFS rejects
The SuSFS patch doesn't match a kernel file. Download the `xcalibur-xf-<device>-<variant>-rejects` artifact and find the `.rej` file.

- If the rejected file is `fs/proc/cmdline.c`, add the port as `devices/patches/<device>-cmdline-susfs-port.patch`. `scripts/ksu.sh` applies it automatically on the next run.
- For any other file, the change has to go into `scripts/ksu.sh`, or into the kernel source you build from. Whitespace-only rejects are ignored automatically.

### Known BakaSU build failures
The workflow looks for two known messages in the build log and adds a clear annotation to the run:

- `You disabled CONFIG_KALLSYMS_ALL`: the static-symbol export is missing or incomplete. Check the `unstatic()` block in `scripts/ksu.sh` and `CONFIG_KALLSYMS` and `CONFIG_KALLSYMS_ALL`.
- `static_export_check.mk`: the BakaSU integration check failed. See the [BakaSU manual integration guide](https://bakasu.org/guide/manual-integrate).

### BakaSU is not at the resolved commit
`scripts/ksu.sh` resolves `KSU_REPO_PIN` (`main` by default) to one commit at the start of the run, then fails with "BakaSU is not at <commit>" if setup didn't check out that commit. Look at the "BakaSU resolved to" line in the log, and confirm that commit exists in the BakaSU repository. The SuSFS pin is `SUSFS_REPO_PIN`, in the same file.

### `kernel_version mismatch`
The `kernel_version` in `devices/<name>.json` doesn't match the kernel's `Makefile`. The preflight step checks this before the build starts. Update the device file.

### Device not offered in the dropdown
A new `devices/<name>.json` file doesn't appear in the *Run workflow* form on its own. Add the name to the `device_codename` options in `bakasu.yml` and `kernelsu.yml`. See [Adding a device](build-susfs.md#adding-a-device).

### Paths after checkout
`bakasu.yml` checks the builder repository out into `builder/`. Any step that calls `scripts/master.sh` from the workspace root must use `builder/scripts/master.sh`. Steps that run inside the kernel tree use the copies staged into `kernel_src/`.

## Workflow calls the wrong branch

Use `${{ github.ref_name }}` instead of a hardcoded branch name when calling a reusable workflow. Note that `build-manager.yml` checks out `dev` by name, so the Manager build always uses the `dev` branch of this repository whatever branch the caller runs from.

---

[← Forking](forking.md) · [Next: History →](history.md)
