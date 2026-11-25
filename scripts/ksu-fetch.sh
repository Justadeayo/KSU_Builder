#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Fetch tiann/KernelSU main, apply patches/ksu, and link the driver into a kernel tree.
# Usage: ksu-fetch.sh <kernel-dir> [patch-dir]   |   KSU_DEST=<dir> ksu-fetch.sh - [patch-dir]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

KDIR="${1:-}"
PATCH_DIRS=("${@:2}")
[ "${#PATCH_DIRS[@]}" -gt 0 ] || PATCH_DIRS=("${SCRIPT_DIR}/../patches/ksu")
UPSTREAM_URL="${KSU_UPSTREAM_URL:-https://github.com/tiann/KernelSU.git}"
UPSTREAM_REF="${KSU_UPSTREAM_REF:-main}"

if [ -n "${KSU_DEST:-}" ]; then
    SOURCE_ONLY=1
    SRC="$KSU_DEST"
else
    SOURCE_ONLY=0
    [ -n "$KDIR" ] && [ "$KDIR" != "-" ] || die "usage: ksu-fetch.sh <kernel-dir> [patch-dir]  (or KSU_DEST=<dir> ksu-fetch.sh - [patch-dir])"
    [ -d "$KDIR" ] || die "kernel dir not found: $KDIR"
    if [ -d "$KDIR/common/drivers" ]; then
        DRIVER_DIR="$KDIR/common/drivers"
    elif [ -d "$KDIR/drivers" ]; then
        DRIVER_DIR="$KDIR/drivers"
    else
        die "no drivers/ directory under $KDIR"
    fi
    # Clone outside the kernel tree so the kernel's own git state is untouched.
    WORK="${KSU_WORKDIR:-$(pwd)/.ksu-work}/$(date +%s)-$$"
    mkdir -p "$WORK"
    SRC="${WORK}/KernelSU"
fi

WORK_ERR="$(mktemp)"
trap 'rm -f "$WORK_ERR"' EXIT

log "Cloning ${UPSTREAM_URL} (${UPSTREAM_REF}) into ${SRC}"
mkdir -p "$SRC"
git init --quiet "$SRC"
git -C "$SRC" remote add origin "$UPSTREAM_URL"
git -C "$SRC" fetch --quiet --tags origin "$UPSTREAM_REF" || die "could not fetch ${UPSTREAM_REF} from ${UPSTREAM_URL}"
git -C "$SRC" checkout --quiet FETCH_HEAD
UPSTREAM_SHA="$(git -C "$SRC" rev-parse HEAD)"
log "Upstream ${UPSTREAM_REF} is at ${UPSTREAM_SHA}"

shopt -s nullglob
PATCHES=()
for d in "${PATCH_DIRS[@]}"; do
    PATCHES+=("${d%/}"/*.patch)
done
shopt -u nullglob
if [ "${#PATCHES[@]}" -eq 0 ]; then
    if [ "${KSU_ALLOW_NO_PATCHES:-0}" = "1" ]; then
        warn "no patches in ${PATCH_DIRS[*]}; building plain upstream ${UPSTREAM_SHA} (KSU_ALLOW_NO_PATCHES=1)"
    else
        die "no patches in ${PATCH_DIRS[*]}. Refusing to build plain upstream; set KSU_ALLOW_NO_PATCHES=1 to allow it."
    fi
else
    log "Applying ${#PATCHES[@]} patch(es) from ${PATCH_DIRS[*]} to the working tree"
    for p in "${PATCHES[@]}"; do
        if ! git -C "$SRC" apply --3way "$(realpath "$p")" 2>"$WORK_ERR"; then
            cat "$WORK_ERR" >&2
            die "patch $(basename "$p") does not apply to upstream ${UPSTREAM_SHA}. Rebase it onto the new upstream and update the patch directories."
        fi
        log "  applied $(basename "$p")"
    done
fi

# The series deletes kernel/Kbuild and builds with the unity Makefile. Kbuild wins over
# Makefile in the same directory, so a Kbuild left behind would drop the build's sources.
[ ! -e "$SRC/kernel/Kbuild" ] || die "kernel/Kbuild is present and would shadow kernel/Makefile"

BUILT_SHA="$(git -C "$SRC" rev-parse HEAD)"
KSU_VERSION=$((30000 + $(git -C "$SRC" rev-list --count HEAD)))
DIFF_SHA="$(git -C "$SRC" diff HEAD | sha256sum | cut -d' ' -f1)"
log "KSU_VERSION=${KSU_VERSION} (upstream commit count, same formula as kernel/Kbuild)"
sed -i -E "s/-DKSU_VERSION=[0-9]+/-DKSU_VERSION=${KSU_VERSION}/" "$SRC/kernel/Makefile"
grep -q "DKSU_VERSION=${KSU_VERSION}\b" "$SRC/kernel/Makefile" || die "could not set KSU_VERSION in kernel/Makefile"

if [ "$SOURCE_ONLY" = 1 ]; then
    log "Source ready at ${SRC} (source-only mode, no kernel tree touched)"
    echo "KSU_SOURCE=${SRC}"
    echo "KSU_VERSION=${KSU_VERSION}"
    exit 0
fi

# The symlink points into the work clone, which must remain until the build finishes.
ln -sfn "${SRC}/kernel" "${DRIVER_DIR}/kernelsu"
log "Linked ${DRIVER_DIR}/kernelsu -> ${SRC}/kernel"

DRIVER_MAKEFILE="${DRIVER_DIR}/Makefile"
DRIVER_KCONFIG="${DRIVER_DIR}/Kconfig"

grep -q "kernelsu/" "$DRIVER_MAKEFILE" 2>/dev/null || printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> "$DRIVER_MAKEFILE"
grep -q 'source "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG" 2>/dev/null || sed -i '/endmenu/i\source "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG"

{
    echo "upstream_url=${UPSTREAM_URL}"
    echo "upstream_ref=${UPSTREAM_REF}"
    echo "upstream_sha=${UPSTREAM_SHA}"
    echo "built_sha=${BUILT_SHA}"
    echo "ksu_version=${KSU_VERSION}"
    echo "patches=${#PATCHES[@]}"
    echo "patch_diff_sha256=${DIFF_SHA}"
} > "${KDIR}/ksu-source.txt"

log "KernelSU built from upstream ${UPSTREAM_SHA} + ${#PATCHES[@]} patch(es)"
echo "KSU_WORK=${WORK}"
