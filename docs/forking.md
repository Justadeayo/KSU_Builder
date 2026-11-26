# Forking

These workflows hardcode several values for `Justadeayo`. Change them before you run the workflows in your own fork. Nothing else needs to change for a basic build.

## Hardcoded values

| File | Value | Change it to |
| :--- | :--- | :--- |
| `devices/violet.json` | `kernel_repo`, `ak3_repo` (`Justadeayo/android_kernel_xiaomi_violet`, `Justadeayo/AnyKernel3`) | Your kernel source and AnyKernel3 fork, or leave them and override per run |
| `scripts/master.sh` | `AK3_REPO` default (`Justadeayo/AnyKernel3`) | Your AnyKernel3 fork, or set `AK3_REPO` in the workflow env |
| `.github/workflows/build-env.yml` | `IMAGE` (`ghcr.io/justadeayo/xcalibur-build-env`) | Your GHCR path. Also update the image name in `bakasu.yml` and `kernelsu.yml` |
| `.github/workflows/bakasu.yml`, `kernelsu.yml` | Build image `ghcr.io/justadeayo/xcalibur-build-env:ubuntu-24.04-clang-r596125` | Same as above |
| `.github/workflows/build-manager.yml` | `repository: 'Justadeayo/KSU_Builder'` and `ref: 'dev'` (three checkouts) | Your fork, e.g. `<you>/KSU_Builder`, and your branch name |
| `.github/workflows/release.yml` | Git identity for the tag (`Justus`, `Justadeayo@users.noreply.github.com`) | Your name and email |
| `.github/workflows/release.yml` | Tag base `v3.3.1` (manual runs), the release notes text (`KernelSU: v3.3.1+`, the `~by Justadeayo` credit line), and the SUSFS patch file name `susfs_patch_to_4.14.patch` that is read for the SUSFS version | Your own version, notes and kernel version |
| `.github/workflows/bakasu.yml`, `kernelsu.yml` | `device_codename` and `clang_version` dropdown options | Only the devices and Clang versions you use |
| `scripts/compile.sh` | `LOCALVERSION` built as `-<kernel_name>-6.0-<variant>` | The kernel version string you want. The `6.0` is fixed in the script and doesn't match the 4.14 kernel |
| `scripts/notify.sh` | Message time zone `Africa/Lagos` and the `WAT` label | Your time zone. `kernelsu.yml` also sets `TZ: Africa/Lagos` |
| `scripts/*.sh` headers | Copyright comments referencing `Justadeayo/KSU_Builder` | Your fork name, if you keep the headers |

`config.env` holds the BakaSU, SUSFS and NoMount sources. They point at upstream projects, so you don't need to change them to fork. Change them only to pin different versions.

## Secrets and variables

Set the secrets listed in [Secrets and outputs](secrets-and-outputs.md) on your fork. The build image is pulled from GHCR, so make the package public or log in with a token that can read it.

## Checklist

1. Fork the repo and set the secrets.
2. Change the values in the table above.
3. Run *Build Env Image* once so the build image exists.
4. Run *KernelSU Kernel Build* with the defaults. It should build violet and send the Telegram messages.
5. Run *BakaSU Kernel Build* the same way to check the BakaSU path.
