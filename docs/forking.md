# Forking

These workflows hardcode several values for `Justadeayo`. Change them before you run the workflows in your own fork. Nothing else needs to change for a basic build.

## Hardcoded values

| File | Value | Change it to |
| :--- | :--- | :--- |
| `devices/violet.json` | `kernel_repo`, `ak3_repo` (`Justadeayo/android_kernel_xiaomi_violet`, `Justadeayo/AnyKernel3`) | Your kernel source and AnyKernel3 fork, or leave them and override per run |
| `scripts/master.sh` | `AK3_REPO` default (`Justadeayo/AnyKernel3`) | Your AnyKernel3 fork, or set `AK3_REPO` in the workflow env |
| `.github/workflows/build-env.yml` | `IMAGE` (`ghcr.io/justadeayo/xcalibur-build-env`) | Your GHCR path. Also update the image name in `bakasu.yml` and `kernelsu.yml` |
| `.github/workflows/bakasu.yml`, `kernelsu.yml` | Build image `ghcr.io/justadeayo/xcalibur-build-env:ubuntu-24.04-clang-r596125` | Same as above |
| `.github/workflows/build-manager.yml` | `repository: 'Justadeayo/KSU_Builder'` (three checkouts) | Your fork, e.g. `<you>/KSU_Builder` |
| `.github/workflows/release.yml` | Git identity for the tag (`Justus`, `Justadeayo@users.noreply.github.com`) and the release credits line | Your name and email |
| `scripts/*.sh` headers | Copyright comments referencing `Justadeayo/KSU_Builder` | Your fork name, if you keep the headers |

## Secrets and variables

Set the secrets listed in [Secrets and outputs](secrets-and-outputs.md) on your fork. The build image is pulled from GHCR, so make the package public or log in with a token that can read it.

## Checklist

1. Fork the repo and set the secrets.
2. Change the values in the table above.
3. Run *Build Env Image* once so the build image exists.
4. Run *KernelSU Kernel Build* with the defaults. It should build violet and send the Telegram messages.
5. Run *BakaSU Kernel Build* the same way to check the BakaSU path.
