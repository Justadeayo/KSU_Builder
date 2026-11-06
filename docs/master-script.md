# Master script

[← Home](../README.md) · [Workflows](workflows.md) · [Build a SUSFS kernel](build-susfs.md) · **Master script** · [Secrets and outputs](secrets-and-outputs.md) · [Forking](forking.md) · [Troubleshooting](troubleshooting.md) · [History](history.md)

---

`scripts/master.sh` holds the steps that the build workflows share: dependencies, Clang, KernelSU setup, compile, AnyKernel3 packaging and ccache cleanup. Telegram messages live in `scripts/notify.sh`. Workflows call it with one line instead of carrying their own copy.

## Commands

```bash
bash scripts/master.sh deps
bash scripts/master.sh clang <clang-version> [dest-dir]
bash scripts/master.sh ksu-setup <kernel-dir> <ksu-type> <defconfig> <setup-url>
bash scripts/master.sh compile <clang-version> <defconfig-target> <kernel-dir> <log-file>
bash scripts/master.sh prune-ccache <cache-key>
bash scripts/master.sh anykernel <boot-dir> <kernel-name> <device> <label> <clang-bin-dir>
bash scripts/master.sh help
```

| Command | What it does |
| :--- | :--- |
| `deps` | Removes stale apt sources, then installs the build packages (one list for every workflow). The build image in `docker/build-env/` installs the same list, so the build workflows no longer call this. |
| `clang` | Downloads and extracts a Clang version into `toolchains/<version>`. Tries the `main-kernel`, `android-14`, `android16-qpr2` and `main` googlesource refs in turn. `clang-r416183b` is cloned from LineageOS. Fails if `bin/clang` is missing afterwards. Skips the download if Clang is already there. |
| `ksu-setup` | Runs a KernelSU or Uni-SU `setup.sh` in the kernel tree, rewrites the fork owner to Justadeayo, and appends the root options to the defconfig. `Uni-SU` is the sKernelSU driver, built without SuSFS. `None` does nothing. The caller gives the `setup.sh` URL and an optional branch (default `master`). |
| `compile` | Exports the Clang and ccache environment, runs `make` and `olddefconfig`, and builds with the log written to the given file. With `REQUIRE_KSU_TAMPER=true` it fails when the final `.config` lost `CONFIG_KSU_TAMPER_SYSCALL_TABLE`. |
| `prune-ccache` | Deletes all but the newest ccache entry for a key. |
| `anykernel` | Copies the kernel image and DTB files from `boot-dir` into an AnyKernel3 folder, fills in the device, Clang version and build date, and zips the result. Prints the zip name on stdout. The `label` sets the zip name. `None`, `NonKSU` and `nsu` turn off `ksu_supported`; any other label turns it on. |

## Environment

| Variable | Used by | Default |
| :--- | :--- | :--- |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | `scripts/notify.sh` | none. If either is missing, notifications are skipped and the build continues. |
| `AK3_REPO`, `AK3_BRANCH` | `anykernel` | `https://github.com/Justadeayo/AnyKernel3.git`, `master` |
| `REQUIRE_KSU_TAMPER` | `compile` | `false` |

## Rules

- `common.sh` provides `log`, `warn` and `die`. The master script sources it.
- Logs go to stderr. Stdout carries only what a command is meant to return, such as the zip name from `anykernel`.
- An unknown command exits with an error. Run `help` to see the list.

## Where each workflow uses it

| Workflow | Commands used |
| :--- | :--- |
| `build.yml`, `build-custom.yml` | none |
| `automated.yml`, `kernel.yml`, `kernel_build.yml` | `clang` (only for a Clang version the image lacks), `ksu-setup`, `compile`, `prune-ccache`, `anykernel` |
| `Kernel_&_Manager_build.yml` | `clang` (only for a Clang version the image lacks), `compile`, `prune-ccache`, `anykernel` |

## Still inline

- The Manager APK delivery in `Dispatch` (`automated.yml`, `Kernel_&_Manager_build.yml`), because it depends on the artifacts each job produces.
- The `build-manager.yml` steps.
- The job-level setup each kernel workflow has: checkout, swap, ccache and the source clone. These need GitHub Actions' own steps or a composite action, so a shell script can't replace them.

---

[← Build a SUSFS kernel](build-susfs.md) · [Next: Secrets and outputs →](secrets-and-outputs.md)

## `scripts/notify.sh`

Every Telegram message comes from this script. Workflows pass the same parameters each time, so a message's layout is set in one place.

- `notify.sh start <device> <kernel> <root> <compiler>` sends the start message. It prints the start time in epoch seconds, which the workflow passes to `finish`.
- `notify.sh finish <device> <kernel> <compiler> <start-epoch> <path:label>...` sends the finish message with the total time and each file's size, then sends each file that exists. Missing paths are skipped.

Failures are never announced. A finish message is sent only from a job that succeeded, so a failed build sends nothing.
