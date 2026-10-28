# Forking

[← Home](../README.md) · [Workflows](workflows.md) · [Build a SUSFS kernel](build-susfs.md) · [Master script](master-script.md) · [Secrets and outputs](secrets-and-outputs.md) · **Forking** · [Troubleshooting](troubleshooting.md) · [History](history.md)

---

If you fork this repository for your own kernel or device, replace these hardcoded values.

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

`build-custom.yml` can override the `devices/violet.json` values per run with its inputs, so you don't need to edit the JSON for a one-off build.

---

[← Secrets and outputs](secrets-and-outputs.md) · [Next: Troubleshooting →](troubleshooting.md)
