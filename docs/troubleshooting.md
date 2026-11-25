# Troubleshooting

[← Home](../README.md) · [Workflows](workflows.md) · [Build a BakaSU SUSFS kernel](build-susfs.md) · [Master script](master-script.md) · [Secrets and outputs](secrets-and-outputs.md) · [Forking](forking.md) · **Troubleshooting** · [History](history.md)

---

## Contents

- [General](#general)
- [BakaSU build framework (`bakasu.yml`)](#bakasu-build-framework-bakasuyml)
- [Workflow calls the wrong branch](#workflow-calls-the-wrong-branch)

## General

### "Cannot find kernel source"
The kernel repo URL or branch is wrong. Check that both exist and use an HTTPS URL. If the value came from `devices/<name>.json`, check the file, or fill in `kernel_source` and `kernel_branch` on the run to override it.

### Kernel compile fails in `olddefconfig`
The defconfig path is wrong, or a symbol dependency is broken. Check the path under `arch/arm64/configs/`. `defconfig_name` is relative to that folder, for example `vendor/xcalibur-perf_defconfig`.

### Out of disk space
The Clang toolchain and kernel source are large. The workflows set up swap space. Check the swap step in the log.

### Telegram messages don't arrive
- The bot token or chat ID is missing or wrong. Check the secrets.
- `scripts/notify.sh` sends nothing when either variable is unset, and the build still runs.
- If Telegram rejects the Markdown, `notify.sh` resends the message as plain text. If the plain send also fails, the chat ID or token is the likely cause.

### Build image pull fails
The build job stops before any step runs if it can't pull `ghcr.io/justadeayo/xcalibur-build-env`. Re-run the job, which is usually enough after a network drop. If it keeps failing, check that the package exists and is public, and that the *Build Env Image* workflow has run at least once. On a fork, see [Forking](forking.md) for the image name.

### Clang downloads on every run
Clang comes from the build image for `clang-r596125`, so it only downloads for other versions. A new `clang_version` creates a new cache, so the first run after a change always downloads. Run from the same branch each time.

### Manager APK missing in the finish message
The Manager APK is attached only when `build_manager` is `true`. Check that input on the run. Also check that *Build Manager* succeeded: if its job failed, the APK isn't in the finish message. `release.yml` always sets `build_manager: true`.

### Artifact or zip missing
Check the job log for the zip name printed by the *Package* step, then look for the artifact with the same name. Artifact names are listed in [Secrets and outputs](secrets-and-outputs.md#where-the-outputs-go).

### `master.sh clang` can't download a version
None of the googlesource refs has that version. Check the name on [googlesource](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86) and add its ref to `cmd_clang` if it lives somewhere new.

## BakaSU build framework (`bakasu.yml`)

### Real SuSFS rejects
The SuSFS patch doesn't match a kernel file. Download the `xcalibur-xf-<device>-<variant>-rejects` artifact and find the `.rej` file. Add a port patch under `devices/patches/` and apply it in `scripts/ksu.sh`.

### BakaSU is not at the pinned commit
`scripts/ksu.sh` checks out `KSU_REPO_PIN` from `config.env` and fails with "BakaSU is not at the pinned commit" when the checkout doesn't match. Confirm the pin exists in the BakaSU repository. The SuSFS pin is `SUSFS_REPO_PIN`, in the same file.

### `kernel_version mismatch`
The `kernel_version` in `devices/<name>.json` doesn't match the kernel's `Makefile`. The preflight step checks this before the build starts. Update the device file.

### `Install build dependencies` fails
`bakasu.yml` checks the builder repository out into `builder/`. Any step that calls `scripts/master.sh` from the workspace root must use `builder/scripts/master.sh`.

## Workflow calls the wrong branch

Use `${{ github.ref_name }}` instead of a hardcoded branch name when calling a reusable workflow.

---

[← Forking](forking.md) · [Next: History →](history.md)
