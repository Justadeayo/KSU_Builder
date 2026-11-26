# KSU_Builder

**Version 3.2**

GitHub Actions workflows for building Android kernels with KernelSU, SUSFS (through BakaSU), and the KernelSU Manager app. Builds default to the Xiaomi Redmi Note 7 Pro (`violet`) with the XCalibur-XF kernel. Other devices need a `devices/<name>.json` file and an entry in the `device_codename` dropdown of `bakasu.yml` and `kernelsu.yml`.

> **Use with caution and at your own risk.** These workflows are for testing, evaluation and customization. Check compatibility with your device before flashing anything, and keep a working boot image or kernel zip somewhere safe. See [`LICENSE`](LICENSE) for the full terms.

---

## Read the docs

| Page | What's in it |
| :--- | :--- |
| [Workflows](docs/workflows.md) | Purpose, triggers, inputs and jobs for every workflow |
| [Build a BakaSU SUSFS kernel](docs/build-susfs.md) | `bakasu.yml`, the framework layout, adding a device |
| [Master script](docs/master-script.md) | `scripts/master.sh` commands and where each workflow uses them |
| [Secrets and outputs](docs/secrets-and-outputs.md) | Repository secrets, artifact names, notify delivery |
| [Forking](docs/forking.md) | Hardcoded values to change in your own fork |
| [Troubleshooting](docs/troubleshooting.md) | Common failures and how to fix them |
| [Credits, license and history](docs/history.md) | Credits, license, support and version history |

---

## Workflows at a glance

| Workflow | Trigger | Purpose | Uses master script |
| :--- | :--- | :--- | :--- |
| `bakasu.yml` (BakaSU Kernel Build) | Manual | Builds a device with BakaSU and SUSFS (`ksu` variant), optionally also a non-root `nsu` variant. Every input is optional, and an empty input uses `devices/<device>.json` | build image, clang, notify, prune-ccache |
| `kernelsu.yml` (KernelSU Kernel Build) | Manual; called by `release.yml` | Builds a device with KernelSU, with SUSFS on by default. Can attach the Manager APK. Every input is optional | build image, clang, ksu-setup, compile, anykernel, notify, prune-ccache |
| `build-manager.yml` (Build Manager) | Manual; called by `kernelsu.yml` | Builds the KernelSU Manager APK and `ksud` binaries | none (self-contained) |
| `build-env.yml` (Build Env Image) | Manual; on changes to `docker/build-env/` | Builds and pushes the build image with the apt packages and `clang-r596125` preinstalled | none (Dockerfile) |
| `release.yml` (Release) | Tag `v*`; manual; called | Builds with `kernelsu.yml` (Manager APK included) and publishes a GitHub Release | none (calls `kernelsu.yml`) |

"Uses master script" lists the shared steps each workflow takes from [`scripts/master.sh`](docs/master-script.md). Steps unique to a workflow stay in that workflow.

---

## Quick start

- **Build violet with BakaSU and SUSFS:** Actions → *BakaSU Kernel Build* → *Run workflow*. See [Build a BakaSU SUSFS kernel](docs/build-susfs.md).
- **Build violet with KernelSU:** Actions → *KernelSU Kernel Build* → *Run workflow*. SUSFS is on by default and can be turned off. See [Workflows](docs/workflows.md#kernelsuyml-kernelsu-kernel-build).
- **Build another device:** add `devices/<name>.json`, add the name to the `device_codename` dropdown in both build workflows, then run the build. Filling in the inputs of a build overrides single values for one run. See [Build a BakaSU SUSFS kernel](docs/build-susfs.md#adding-a-device) and [Forking](docs/forking.md).
