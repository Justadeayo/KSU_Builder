#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Based on Zincore Forge by yureixen (https://github.com/yureixen/zincore-forge).
# Copied and modified for Justadeayo/KSU_Builder. Licensed under GPL-2.0; see LICENSE-GPL-2.0.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

DEVICE="${1:?Usage: variant.sh <device> <variant>}"
VARIANT="${2:?Usage: variant.sh <device> <variant>}"

case "$VARIANT" in
    nsu) log "NSU (stock) variant — nothing to add" ;;
    ksu)
        log "KSU variant — applying BakaSU + SuSFS"
        bash "${SCRIPT_DIR}/ksu.sh" "$DEVICE"
        ;;
    *) die "Unknown variant '$VARIANT' — expected nsu or ksu" ;;
esac

log "variant.sh done for variant: $VARIANT"
