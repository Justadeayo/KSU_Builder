#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Based on Zincore Forge by yureixen (https://github.com/yureixen/zincore-forge).
# Copied and modified for Justadeayo/KSU_Builder. Licensed under GPL-2.0; see LICENSE-GPL-2.0.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

DEVICE="${1:?Usage: ksu.sh <device>}"
DEVICE_JSON="devices/${DEVICE}.json"

: "${KSU_REPO_URL:?KSU_REPO_URL not set — source config.env first}"
: "${KSU_REPO_BRANCH:?KSU_REPO_BRANCH not set — source config.env first}"
: "${SUSFS_REPO_URL:?SUSFS_REPO_URL not set — source config.env first}"
: "${SUSFS_REPO_PIN:?SUSFS_REPO_PIN not set — source config.env first}"

KERNEL_VERSION=$(read_field kernel_version)
[ -n "$KERNEL_VERSION" ] || die "kernel_version missing in $DEVICE_JSON"

# Clone + pin dependencies BEFORE executing anything from them
WORKDIR="$(pwd)"
KSU_SRC="${WORKDIR}/.xcalibur-xf_deps/kernelsu"
SUSFS_SRC="${WORKDIR}/.xcalibur-xf_deps/susfs"
mkdir -p "$(dirname "$KSU_SRC")"

log "Cloning KernelSU (${KSU_REPO_URL}, branch ${KSU_REPO_BRANCH}, depth 1)"
rm -rf "$KSU_SRC"
git clone --quiet --depth 1 --branch "$KSU_REPO_BRANCH" "$KSU_REPO_URL" "$KSU_SRC"

log "Cloning SuSFS source (JackA1ltman, pinned to ${SUSFS_REPO_PIN})"
git init --quiet "$SUSFS_SRC"
git -C "$SUSFS_SRC" remote add origin "$SUSFS_REPO_URL"
git -C "$SUSFS_SRC" fetch --quiet --depth 1 origin "$SUSFS_REPO_PIN"
git -C "$SUSFS_SRC" checkout --quiet FETCH_HEAD

FRAGMENT_DIR="xcalibur-xf_fragments"
FRAGMENT_FILE="${FRAGMENT_DIR}/kernelsu.config"
mkdir -p "$FRAGMENT_DIR"
: > "$FRAGMENT_FILE"

log "Installing KernelSU (branch ${KSU_REPO_BRANCH})"
# setup.sh in the fork still names the upstream clone; point it at this fork.
sed 's|backslashxx/KernelSU|Justadeayo/KernelSU|g' "${KSU_SRC}/kernel/setup.sh" > "${KSU_SRC}/kernel/setup.fork.sh"
bash "${KSU_SRC}/kernel/setup.fork.sh" "$KSU_REPO_BRANCH"
[ -d KernelSU/kernel ] || die "KernelSU was not installed into the kernel tree, check kernel/setup.sh"

log "Applying SuSFS patch for kernel $KERNEL_VERSION"

if grep -q "CONFIG_KSU_SUSFS" "fs/namespace.c" 2>/dev/null; then
    log "SuSFS already patched in this tree, skipping patch step"
else
    SUSFS_PATCH_FILE="${SUSFS_SRC}/Patches/Patch/susfs_patch_to_${KERNEL_VERSION}.patch"

    if [ ! -f "$SUSFS_PATCH_FILE" ]; then
        die "$SUSFS_PATCH_FILE not found in pinned SuSFS source — check that susfs_patch_to_${KERNEL_VERSION}.patch exists at this pinned commit."
    fi

    log "Applying SuSFS patch"
    set +e
    patch -p1 --fuzz=3 < "$SUSFS_PATCH_FILE"
    PATCH_RC=$?
    set -e
    if [ "$PATCH_RC" -gt 1 ]; then
        die "patch exited with code $PATCH_RC — not a hunk rejection but a fatal patch error (malformed patch, unreadable target file). Check $SUSFS_PATCH_FILE."
    fi
    
    # Branch-specific port. Some kernel branches differ from upstream in files
    # the SuSFS patch touches, so the rejected hunks are applied by hand.
    # The port is picked by device and branch:
    #   devices/patches/<device>-<kernel_branch>-susfs-port.patch
    # Branches without their own port fall back to the older
    # devices/patches/<device>-cmdline-susfs-port.patch, when fs/proc/cmdline.c rejected.
    BRANCH=$(read_field kernel_branch)
    PORT_PATCH="devices/patches/${DEVICE}-${BRANCH}-susfs-port.patch"
    LEGACY_PORT="devices/patches/${DEVICE}-cmdline-susfs-port.patch"
    if [ ! -f "$PORT_PATCH" ] && [ -f fs/proc/cmdline.c.rej ] && [ -f "$LEGACY_PORT" ]; then
        PORT_PATCH="$LEGACY_PORT"
    fi

    if [ -f "$PORT_PATCH" ] && [ -n "$(find . -path ./.xcalibur-xf_deps -prune -o -name '*.rej' -print -quit)" ]; then
        log "Applying device port for branch ${BRANCH} ($PORT_PATCH)"
        patch -p1 < "$PORT_PATCH" || die "device port $PORT_PATCH failed to apply"
        # Remove the rejects this port resolves (every file it patches).
        sed -nE 's#^\+\+\+ [^/]+/([^[:space:]]+).*#\1#p' "$PORT_PATCH" | while read -r f; do
            rm -f -- "${f}.rej"
        done
    fi

    # A reject is ignored only if it is whitespace-only
    ws_only() {
        awk '
            /^--- / || /^\+\+\+ / || /^@@/ { next }
            /^-/ { s = substr($0, 2); gsub(/[[:space:]]/, "", s); m[++nm] = s; next }
            /^\+/ { s = substr($0, 2); gsub(/[[:space:]]/, "", s); p[++np] = s; next }
            END {
                if (nm == 0 || nm != np) exit 1
                for (i = 1; i <= nm; i++) if (m[i] != p[i]) exit 1
            }' "$1"
    }

    REAL_REJ=()
    while IFS= read -r -d '' rej; do
        if ws_only "$rej"; then
            log "Whitespace-only reject ignored: $rej"
            rm -f -- "$rej"
        else
            REAL_REJ+=("$rej")
        fi
    done < <(find . -path ./.xcalibur-xf_deps -prune -o -name '*.rej' -print0 2>/dev/null)

    if [ "${#REAL_REJ[@]}" -gt 0 ]; then
        warn "SuSFS patch produced real rejected hunks:"
        for r in "${REAL_REJ[@]}"; do warn "  $r"; done
        die "These must be resolved manually against this kernel tree before a KSU build can be trusted."
    fi
    log "SuSFS patch applied cleanly (no real rejects)"
fi

# Manual hook script
log "Applying SuSFS manual hook patches"
# Run only SuSFS's own hook edits. Lines that insert KernelSU hook calls
# (ksu_*, CONFIG_KSU) are dropped: this driver runs su grants through its
# syscall table (CONFIG_KSU_TAMPER_SYSCALL_TABLE), so those calls are not needed
# and would not link against it.
FILTERED_HOOKS="${WORKDIR}/.xcalibur-xf_deps/susfs_inline_hook_patches.filtered.sh"
sed -E '/^[[:space:]]*sed -i.*(ksu_|CONFIG_KSU\b|a\\#endif)/s/^([[:space:]]*)sed -i/\1true # skipped KernelSU hook or its #endif: sed -i/' "${SUSFS_SRC}/Patches/susfs_inline_hook_patches.sh" > "$FILTERED_HOOKS"
bash "$FILTERED_HOOKS" | tee /tmp/xcalibur-xf_susfs_hook.log
# The SuSFS inline-hook script adds calls to three KernelSU hooks from the
# older API that this fork does not expose to the kernel tree (sys_read, fstat,
# init.rc, setprocattr). The fork already hooks setprocattr through its LSM list
# (lsm_hooks_list.c), so the call in selinux/hooks.c is redundant. SuSFS's own
# inserts are left alone.
python3 - <<'PY'
import pathlib, re
NAMES = ("ksu_is_init_rc_hook_enabled", "ksu_handle_sys_read", "ksu_handle_vfs_fstat", "ksu_hide_setprocattr")
BLOCK = re.compile(r"#ifdef CONFIG_KSU\n(.*?)#endif[^\n]*\n", re.S)
removed = 0
for path in ("fs/read_write.c", "fs/stat.c", "security/selinux/hooks.c"):
    f = pathlib.Path(path)
    if not f.exists():
        continue
    text = f.read_text()
    def drop(m):
        global removed
        if any(n in m.group(1) for n in NAMES):
            removed += 1
            return ""
        return m.group(0)
    text = BLOCK.sub(drop, text)
    lines = []
    for line in text.splitlines(keepends=True):
        if any(n in line for n in NAMES):
            removed += 1
            continue
        lines.append(line)
    f.write_text("".join(lines))
print(f"Removed {removed} legacy KernelSU hook call(s) that this driver does not provide")
PY

grep -o "Current susfs patch version:[0-9.]*" /tmp/xcalibur-xf_susfs_hook.log | head -1 | sed 's/Current susfs patch version://' > "${WORKDIR}/${DEVICE}-susfs-version.txt" || true
[ -s "${WORKDIR}/${DEVICE}-susfs-version.txt" ] || die "SuSFS hook script ran but no patch version was found in /tmp/xcalibur-xf_susfs_hook.log, the version grep may be out of date"

# Core config fragment (structural — merged into out/.config by compile.sh)
log "Patching static symbol exports required by KernelSU"

UNSTATIC_APPLIED=0
UNSTATIC_TOTAL=0

unstatic() {
    local file="$1" regex="$2"
    UNSTATIC_TOTAL=$((UNSTATIC_TOTAL + 1))

    if [ ! -f "$file" ]; then
        warn "unstatic: $file not found in this tree — skipping '$regex' (expected if this kernel's source layout differs)"
        return
    fi

    if grep -q "static $regex" "$file" 2>/dev/null; then
        sed -i "s/static $regex/$regex/" "$file"
        log "  exported: $regex ($file)"
        UNSTATIC_APPLIED=$((UNSTATIC_APPLIED + 1))
    else
        warn "  not found as 'static $regex' in $file — already non-static, or this kernel tree's SELinux code differs from what this pattern expects"
    fi
}
unstatic "security/selinux/selinuxfs.c" "ssize_t (\*write_op\[\])"
unstatic "security/selinux/selinuxfs.c" "const struct file_operations sel_handle_status_ops"
unstatic "security/selinux/selinuxfs.c" "DEFINE_MUTEX(sel_mutex);"
unstatic "security/selinux/ss/services.c" "struct page \*selinux_status_page;"
unstatic "security/selinux/ss/services.c" "DEFINE_MUTEX(selinux_status_lock);"
unstatic "security/selinux/ss/services.c" "DEFINE_RWLOCK(policy_rwlock);"
unstatic "security/selinux/hooks.c" "struct security_operations selinux_ops"
unstatic "security/selinux/ss/services.c" "void security_dump_masked_av("
unstatic "security/selinux/ss/services.c" "void context_struct_compute_av("

log "Static-symbol export summary: ${UNSTATIC_APPLIED}/${UNSTATIC_TOTAL} applied"
if [ "$UNSTATIC_APPLIED" -lt "$UNSTATIC_TOTAL" ]; then
    warn "$((UNSTATIC_TOTAL - UNSTATIC_APPLIED)) pattern(s) above were NOT applied — this is expected if they're already non-static in this tree, but if this is a NEW kernel source (different repo/version than previously verified), manually confirm KernelSU actually has the symbol access it needs before trusting this build."
fi

fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_SUS_PATH"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_SUS_MOUNT"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_SUS_KSTAT"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_SPOOF_UNAME"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_ENABLE_LOG"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_OPEN_REDIRECT"
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_SUSFS_SUS_MAP"
# Root grant hooks. The fork's Kconfig recommends the syscall-table tamper for
# 3.0-4.14 kernels, and sucompat (su grant) runs through it. Without this option
# the su grant hooks are not compiled in and root requests fail.
fragment_add "$FRAGMENT_FILE" "-e CONFIG_KSU_TAMPER_SYSCALL_TABLE"

# THREAD_INFO_IN_TASK is conditionally required
if grep -q "THREAD_INFO_IN_TASK" "drivers/kernelsu/Kconfig" 2>/dev/null; then
    fragment_add "$FRAGMENT_FILE" "-e CONFIG_THREAD_INFO_IN_TASK"
    log "THREAD_INFO_IN_TASK required by this KernelSU Kconfig, added"
fi

log "Fragment written: $FRAGMENT_FILE"
cat "$FRAGMENT_FILE"
