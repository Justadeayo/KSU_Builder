#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Fetches tiann/KernelSU at the tip of its main branch, applies this repo's patch series, and wires the driver into a kernel tree.
#
# Usage: ksu-fetch.sh <kernel-dir> [patch-dir]
#   kernel-dir  kernel source tree (must contain drivers/Makefile and drivers/Kconfig)
#   patch-dir   directory of *.patch files, applied in lexical order (default: patches/ksu)
#
# Environment overrides (for testing or mirrors):
#   KSU_UPSTREAM_URL  default https://github.com/tiann/KernelSU.git
#   KSU_UPSTREAM_REF  default main
#
# Always tracks the upstream branch tip; nothing is pinned. If a patch no longer applies to the current upstream, the script stops and names the patch.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

KDIR="${1:?usage: ksu-fetch.sh <kernel-dir> [patch-dir]}"
PATCH_DIR="${2:-patches/ksu}"
UPSTREAM_URL="${KSU_UPSTREAM_URL:-https://github.com/tiann/KernelSU.git}"
UPSTREAM_REF="${KSU_UPSTREAM_REF:-main}"

[ -d "$KDIR" ] || die "kernel dir not found: $KDIR"

# Pick the driver directory the same way tiann's setup.sh does.
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

log "Cloning ${UPSTREAM_URL} (${UPSTREAM_REF})"
git init --quiet "$SRC"
git -C "$SRC" remote add origin "$UPSTREAM_URL"
git -C "$SRC" fetch --quiet --tags origin "$UPSTREAM_REF" || die "could not fetch ${UPSTREAM_REF} from ${UPSTREAM_URL}"
git -C "$SRC" checkout --quiet FETCH_HEAD
UPSTREAM_SHA="$(git -C "$SRC" rev-parse HEAD)"
log "Upstream ${UPSTREAM_REF} is at ${UPSTREAM_SHA}"

# Apply the patches to the working tree
shopt -s nullglob
PATCHES=("${PATCH_DIR%/}"/*.patch)
shopt -u nullglob
if [ "${#PATCHES[@]}" -eq 0 ]; then
    warn "no patches in ${PATCH_DIR}; building plain upstream ${UPSTREAM_SHA}"
else
    log "Applying ${#PATCHES[@]} patch(es) from ${PATCH_DIR} to the working tree"
    for p in "${PATCHES[@]}"; do
        if ! git -C "$SRC" apply --3way "$(realpath "$p")" 2>"${WORK}/apply.err"; then
            cat "${WORK}/apply.err" >&2
            die "patch $(basename "$p") does not apply to upstream ${UPSTREAM_SHA}. Rebase it onto the new upstream and update ${PATCH_DIR}."
        fi
        log "  applied $(basename "$p")"
    done
fi

# Upstream's kernel/Kbuild computes the version. 
git -C "$SRC" checkout --quiet "$UPSTREAM_SHA" -- kernel/Kbuild || die "upstream has no kernel/Kbuild"

BUILT_SHA="$(git -C "$SRC" rev-parse HEAD)"
KSU_VERSION=$((30000 + $(git -C "$SRC" rev-list --count HEAD)))
DIFF_SHA="$(git -C "$SRC" diff HEAD | sha256sum | cut -d' ' -f1)"
log "KSU_VERSION=${KSU_VERSION} (upstream commit count, same formula as kernel/Kbuild)"

# Link the driver into the kernel tree, as tiann's setup.sh does.
ln -sfn "${SRC}/kernel" "${DRIVER_DIR}/kernelsu"
log "Linked ${DRIVER_DIR}/kernelsu -> ${SRC}/kernel"

DRIVER_MAKEFILE="${DRIVER_DIR}/Makefile"
DRIVER_KCONFIG="${DRIVER_DIR}/Kconfig"

grep -q "kernelsu/" "$DRIVER_MAKEFILE" 2>/dev/null || printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> "$DRIVER_MAKEFILE"
grep -q 'source "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG" 2>/dev/null || sed -i '/endmenu/i\source "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG"

# Record exactly what was built, for logs and release notes.
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
