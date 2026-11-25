#!/usr/bin/env bash
# Apply the pinned SuSFS kernel side to a kernel tree for KernelSU.
# Usage: susfs-setup.sh <kernel-dir> <kernel-version> <device>
set -euo pipefail

KDIR="${1:?kernel dir}"
KVER="${2:?kernel version, e.g. 4.14}"
DEVICE="${3:?device codename, e.g. violet}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../config.env"
source "${SCRIPT_DIR}/common.sh"

: "${SUSFS_REPO_URL:?SUSFS_REPO_URL not set}"
: "${SUSFS_REPO_PIN:?SUSFS_REPO_PIN not set}"

SUSFS_SRC="$(mktemp -d)/susfs"
log "Fetching SuSFS (JackA1ltman) at ${SUSFS_REPO_PIN}"
git init -q "$SUSFS_SRC"
git -C "$SUSFS_SRC" remote add origin "$SUSFS_REPO_URL"
git -C "$SUSFS_SRC" fetch -q --depth 1 origin "$SUSFS_REPO_PIN"
git -C "$SUSFS_SRC" checkout -q FETCH_HEAD

cd "$KDIR"

[ -f drivers/kernelsu/Kconfig ] || die "drivers/kernelsu/Kconfig missing in ${KDIR}, ksu-fetch did not link KernelSU"
if ! grep -q "config KSU_SUSFS" drivers/kernelsu/Kconfig; then
    log "Adding SuSFS Kconfig to KernelSU"
    cat "${SCRIPT_DIR}/../patches/susfs/Kconfig.susfs" >> drivers/kernelsu/Kconfig
fi

if grep -q "CONFIG_KSU_SUSFS" fs/namespace.c 2>/dev/null; then
    log "SuSFS already present in ${KDIR}, skipping"
else
    PATCH_FILE="${SUSFS_SRC}/Patches/Patch/susfs_patch_to_${KVER}.patch"
    [ -f "$PATCH_FILE" ] || die "susfs_patch_to_${KVER}.patch missing at pin ${SUSFS_REPO_PIN}"

    log "Applying SuSFS kernel patch for ${KVER}"
    rc=0
    patch -p1 --fuzz=3 --no-backup-if-mismatch < "$PATCH_FILE" || rc=$?
    # 1 = some hunks rejected; anything else is a fatal patch error
    [ "$rc" -le 1 ] || die "patch exited ${rc}: malformed patch or unreadable target"

    # Device port (kept in this repo): only needed when upstream's cmdline hunk rejected
    PORT="${SCRIPT_DIR}/../devices/patches/${DEVICE}-cmdline-susfs-port.patch"
    if [ -f fs/proc/cmdline.c.rej ]; then
        [ -f "$PORT" ] || die "fs/proc/cmdline.c rejected and no port at ${PORT}"
        log "Applying ${DEVICE} cmdline SuSFS port"
        patch -p1 < "$PORT" || die "device port failed to apply"
        rm -f fs/proc/cmdline.c.rej
    fi

    # Only whitespace-only rejects are tolerated
    real=0
    while IFS= read -r rej; do
        if grep -E '^[+-]' "$rej" | grep -v '^[+-][[:space:]]*$' | grep -v -E '^(\+\+\+|---) ' | grep -q .; then
            warn "real rejected hunk: $rej"
            real=1
        else
            log "whitespace-only reject ignored: $rej"
        fi
    done < <(find . -name '*.rej' -not -path './.git/*')
    [ "$real" -eq 0 ] || die "SuSFS patch has real rejected hunks"
    log "SuSFS kernel patch applied"
fi

log "Applying SuSFS inline hook patches"
bash "${SUSFS_SRC}/Patches/susfs_inline_hook_patches.sh"

rm -rf "$(dirname "$SUSFS_SRC")"
log "SuSFS setup complete for ${DEVICE}"
