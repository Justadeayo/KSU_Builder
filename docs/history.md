# Credits, license and history

[← Home](../README.md) · [Workflows](workflows.md) · [Build a SUSFS kernel](build-susfs.md) · [Master script](master-script.md) · [Secrets and outputs](secrets-and-outputs.md) · [Forking](forking.md) · [Troubleshooting](troubleshooting.md) · **History**

---

## Contents

- [Credits](#credits)
- [License](#license)
- [Support](#support)
- [Version history](#version-history)

## Credits

- [yureixen](https://github.com/yureixen/zincore-forge) for Zincore Forge, whose framework `build.yml` is based on. Zincore Forge is licensed under GPL-2.0.

## License

- The license in [`LICENSE`](../LICENSE) covers the files written for this repository.
- Files copied or adapted from [Zincore Forge](https://github.com/yureixen/zincore-forge) are licensed under **GPL-2.0**. Each has a header comment, and the GPL-2.0 text is in [`LICENSE-GPL-2.0`](../LICENSE-GPL-2.0). These are `scripts/common.sh`, `compile.sh`, `env.sh`, `ksu.sh`, `variant.sh`, `config.env`, `.github/workflows/build.yml` and `.github/workflows/build-custom.yml`.

## Support

Report problems through GitHub Issues. Include the workflow name, the device, the kernel source and branch, and the error log. Support is best-effort.

## Version history

| Version | Date | Notes | Branch |
| :--- | :--- | :--- | :--- |
| **2.6** | 2026-10-28 | Driver moved from BakaSU to `Justadeayo/KernelSU` (master, depth-1 clone, no commit pin). `ksu.sh` rewrites the fork's `setup.sh` to clone the fork. BakaSU names replaced with KernelSU across workflows and docs. `compile.sh` records the KernelSU clone's `git describe`. `ReSukiSU` removed from `kernel.yml` and renamed to `BakaSU` in `kernel_build.yml`, which clones `Justadeayo/sKernelSU`. `ReSukiSU` no longer adds `CONFIG_KSU_SUSFS=y`. Manager `sed` in `build-manager.yml` now targets `Justadeayo/KernelSU`. | `dev` |
| **2.5** | 2026-10-28 | Added `build-custom.yml`, a standalone copy of `build.yml` with optional inputs for device, kernel source, branch, defconfig, Clang, AnyKernel3 and Telegram. Empty inputs use `devices/<device>.json`. Split the README into linked pages under `docs/`. `ksu.sh` picks the SUSFS port by device and branch (`devices/patches/<device>-<kernel_branch>-susfs-port.patch`), with the old cmdline port as a fallback. Added the violet 16.3 port. | `dev` |
| **2.4** | 2026-10-28 | Added `scripts/master.sh` with the shared dependency, Clang, Telegram, AnyKernel3, KernelSU setup, compile, failure-report and ccache-prune steps. Wired the kernel workflows and `build.yml` to it. Telegram sends retry as plain text when Markdown is rejected. | `dev` |
| **2.3** | 2026-10-28 | Added `build.yml` (Build SUSFS Kernel) with `devices/*.json`, pinned `config.env` and the `scripts/` framework. Violet targets Justadeayo/android_kernel_xiaomi_violet branch `17` with a SuSFS cmdline port patch. | `dev` |
| **2.2** | 2026-10-18 | Base release tag and version references bumped from `v3.3.0` to `v3.3.1` in `release.yml`, `build-manager.yml` and the README. | `dev` |
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

[← Troubleshooting](troubleshooting.md) · [Home](../README.md)
