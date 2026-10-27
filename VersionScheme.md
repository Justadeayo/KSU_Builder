
## 📑 Version History

| Version | Date | Notes | Branch |
| :--- | :--- | :--- | :--- |
| **2.3** | 2026-10-26 | Include Support for SUSFS in `kernel.yml` | `dev` |
| **2.2** | 2026-10-18 | Base release tag and version references bumped from `v3.3.0` to `v3.3.1` across `release.yml`, `build-manager.yml` and README | `dev` |
| **2.1** | 2026-10-06 | Shared Clang cache and ccache compiler check across all kernel workflows; moved Telegram delivery of `automated.yml` and `Kernel_&_Manager_build.yml` into a `Dispatch` job so the Manager APK is always attached; `release.yml` no longer sends a Telegram success message and `build-manager.yml` now sets the Manager version code from the fork's Makefile `KSU_VERSION` (else the default Gradle version) with version name `v3.3.0`; added `clang-r596125` to `Kernel_&_Manager_build.yml`; README synced with all workflows | `dev` |
| **2.0** | 2026-09-19 | Refactored `kernel_build.yml` to be a dynamic version of `kernel.yml` in terms of KSU_REPO branch, updated build manager workflow steps to match upstream | `dev` |
| **1.9** | 2026-09-13 | Updated `sync.yml` to daily cron schedule; renamed `release.yml` job from `Full-Release` to `build`; refactored prerelease logic to default external calls to prerelease | `dev` |
| **1.8** | 2026-09-11 | Stripped out SUSFS patch URL dependencies across all active kernel workflows | `dev` |
| **1.7** | 2026-09-11 | Refactor release to be prerelease on workflow call and full release on workflow dispatch | `dev` |
| **1.6** | 2026-09-08 | Refactor workflows to work from secondary repository, implemented the use of PAT to communicate with KernelSU Repo `(for sync.yml)`, dynamic naming of flashable zip file | `dev` |
| **1.5** | 2026-09-07 | Updated workflow count to 7, designated `kernel.yml` as main standalone, added `kernel_build.yml` (extra), updated `Kernel_&_Manager_build.yml` with dynamic `kernel_name` and Telegram `--data-urlencode` payload fixes. | `dev` |
| **1.4** | 2026-09-05 | Added kernel.yml for standalone kernel builds & supported `clang-r416183b` for faster build | `dev` |
| **1.3** | 2026-09-01 | Extended parameter customization, SuSFS 4.14 patch automation, and hardcode mapping guide | `dev` |
| **1.2** | 2026-08-19 | Automated upstream synchronization and scheduled release triggers | `dev`, `test` |
| **1.1** | 2026-07-26 | Dynamic workflow references and interactive dispatch parameters | `dev`, `test` |
| **1.0** | 2026-07-20 | Initial automated kernel & manager build release | `test` |
