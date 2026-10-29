# KSU_Builder

GitHub Actions workflows for building Android kernels with KernelSU or SUSFS, and the KernelSU Manager app. The current target is the Xiaomi Redmi Note 7 Pro (`violet`) with the XCalibur-XF kernel.

> **Use with caution and at your own risk.** These workflows are for testing, evaluation and customization. Check compatibility with your device before flashing anything, and keep a working boot image or kernel zip somewhere safe. See [`LICENSE`](LICENSE) for the full terms.

---

## Read the docs

| Page | What's in it |
| :--- | :--- |
| [Workflows](docs/workflows.md) | Purpose, triggers, inputs and jobs for every workflow |
| [Build a SUSFS kernel](docs/build-susfs.md) | `build.yml` and `build-custom.yml`, the framework layout, adding a device |
| [Master script](docs/master-script.md) | `scripts/master.sh` commands and where each workflow uses them |
| [Secrets and outputs](docs/secrets-and-outputs.md) | Repository secrets, artifact names, Telegram delivery |
| [Forking](docs/forking.md) | Hardcoded values to change in your own fork |
| [Troubleshooting](docs/troubleshooting.md) | Common failures and how to fix them |
| [Credits, license and history](docs/history.md) | Credits, license, support and version history |

---

## Workflows at a glance

| Workflow | Trigger | Purpose | Uses master script |
| :--- | :--- | :--- | :--- |
| `build.yml` (Build XCalibur-XF SUSFS Kernel) | Manual | Builds violet in two variants: `ksu` is BakaSU with SuSFS, `nsu` is a non-root build without SuSFS, from the `devices/` framework | deps, Telegram |
| `build-custom.yml` (Build Custom SUSFS Kernel) | Manual | Same build as `build.yml`, but every setting can be overridden with an input | deps, Telegram |
| `automated.yml` (Automated Build for Violet) | Manual, or called by `release.yml` | Fixed-target kernel and Manager build for violet, with Telegram delivery | deps, clang, ksu-setup, compile, fail-report, prune-ccache, Telegram, AnyKernel3 |
| `kernel.yml` (Kernel Build (main)) | Manual | Standalone kernel build from any source. No Manager APK | deps, clang, ksu-setup, compile, fail-report, prune-ccache, Telegram, AnyKernel3 |
| `kernel_build.yml` (Kernel Build (extra)) | Manual | Same as `kernel.yml`, plus a KernelSU branch choice and raw outputs for testing | deps, clang, ksu-setup, compile, fail-report, prune-ccache, Telegram, AnyKernel3 |
| `Kernel_&_Manager_build.yml` (Kernel & Manager Build) | Manual | Kernel and Manager APK together, both sent to Telegram | deps, clang, compile, fail-report, prune-ccache, Telegram, AnyKernel3 |
| `build-manager.yml` (Build Manager) | Push to `main`, `dev`, `ci`, `test`, `staging`; called; manual | Builds the KernelSU Manager APK and `ksud` binaries | none (self-contained) |
| `release.yml` (Release) | Tag `v*`; manual; called | Publishes a GitHub Release from the automated build | none (calls `automated.yml`) |
| `sync.yml` (Sync Upstream Updates) | Daily at 00:00 UTC; manual | Keeps the KernelSU fork aligned with upstream | none |

"Uses master script" lists the shared steps each workflow takes from [`scripts/master.sh`](docs/master-script.md). Steps unique to a workflow stay in that workflow.

---

## Quick start

- **Build violet with SUSFS:** Actions → *Build XCalibur-XF SUSFS Kernel (violet)* → *Run workflow*. See [Build a SUSFS kernel](docs/build-susfs.md).
- **Build a different kernel source:** Actions → *Kernel Build (main)* → fill in the kernel source, branch, defconfig and device. See [Workflows](docs/workflows.md#kernelyml-kernel-build-main).
- **Build the Manager APK:** push to `dev`, or run *Build Manager* by hand. See [Workflows](docs/workflows.md#build-manageryml-build-manager).
- **Publish a release:** push a `v*` tag, or run *Release* by hand. See [Workflows](docs/workflows.md#releaseyml-release).

---

← Next: [Workflows](docs/workflows.md)
