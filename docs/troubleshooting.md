# Troubleshooting

[← Home](../README.md) · [Workflows](workflows.md) · [Build a SUSFS kernel](build-susfs.md) · [Master script](master-script.md) · [Secrets and outputs](secrets-and-outputs.md) · [Forking](forking.md) · **Troubleshooting** · [History](history.md)

---

## Contents

- [General](#general)
- [Build framework (`build.yml`, `build-custom.yml`)](#build-framework-buildyml-build-customyml)
- [Workflow calls the wrong branch](#workflow-calls-the-wrong-branch)

## General

### "Cannot find kernel source"
The kernel repo URL or branch is wrong. Check that both exist and use an HTTPS URL.

### Kernel compile fails in `olddefconfig`
The defconfig path is wrong, or a symbol dependency is broken. Check the path under `arch/arm64/configs/`.

### Out of disk space
The Clang toolchain and kernel source are large. The workflows set up swap space. Check the swap step in the log.

### Telegram messages don't arrive
- The bot token or chat ID is missing or wrong. Check the secrets.
- A missing secret skips the Telegram steps without failing the build.
- If Telegram rejects the Markdown, `master.sh` resends the message as plain text. If the plain send also fails, the chat ID or token is the likely cause.

### Clang downloads on every run
GitHub caches are visible only to the branch that created them, or to the default branch. A new `clang_version` creates a new cache, so the first run after a change always downloads. Run from the same branch each time.

### Manager APK missing in Telegram
`build-manager` failed or was skipped (for example, `ksu_type` is `None`). Check the `Dispatch` job for the "No manager APK found" warning, then check the `build-manager` result.

### Artifact or zip missing
Check the job log for errors. Zip names follow `<kernel-name>_<device>_<label>_<timestamp>`. Make sure the artifact name you're looking for matches.

### `master.sh clang` can't download a version
None of the googlesource refs has that version. Check the name on [googlesource](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86) and add its ref to `cmd_clang` if it lives somewhere new.

## Build framework (`build.yml`, `build-custom.yml`)

### Real SuSFS rejects
The SuSFS patch doesn't match a kernel file. Download the `-rejects` artifact and find the `.rej` file. Add a port patch under `devices/patches/` and apply it in `ksu.sh`.

### KernelSU is not at the pinned commit
`setup.sh` couldn't check out `KSU_REPO_PIN` and fell back to the default branch. Confirm the pin exists in the KernelSU repository.

### `kernel_version mismatch`
`kernel_version` in `devices/<name>.json`, or the `kernel_version` input in `build-custom.yml`, doesn't match the kernel's `Makefile`. Update it.

### `Install build dependencies` fails in `build.yml`
`build.yml` checks the repository out into `builder/`. Any step that calls `scripts/master.sh` from the workspace root must use `builder/scripts/master.sh`.

## Workflow calls the wrong branch

Use `${{ github.ref_name }}` instead of a hardcoded branch name when calling a reusable workflow.

---

[← Forking](forking.md) · [Next: History →](history.md)
