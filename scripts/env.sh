#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Based on Zincore Forge by yureixen (https://github.com/yureixen/zincore-forge).
# Copied and modified for Justadeayo/KSU_Builder. Licensed under GPL-2.0; see LICENSE-GPL-2.0.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

DEVICE="${1:?Usage: env.sh <device>}"
DEVICE_JSON="devices/${DEVICE}.json"

[ -f "$DEVICE_JSON" ] || die "No device config found at $DEVICE_JSON"

KERNEL_REPO=$(read_field kernel_repo)
KERNEL_BRANCH=$(read_field kernel_branch)
CLANG_VERSION=$(read_field clang_version)
KERNEL_ARCH=$(read_field arch)

[ -n "$KERNEL_ARCH" ] || die "No arch set in $DEVICE_JSON for device '$DEVICE'"
if [ "$KERNEL_ARCH" != "arm64" ]; then
    die "env.sh only supports arch=arm64 — device '$DEVICE' declares arch='$KERNEL_ARCH'."
fi

[ -n "$CLANG_VERSION" ] || die "No clang_version set in $DEVICE_JSON for device '$DEVICE'"

log "Device: $DEVICE"
log "Kernel: $KERNEL_REPO ($KERNEL_BRANCH)"
log "Clang:  clang-$CLANG_VERSION"

# Resolve Clang toolchain
CLANG_DIR="$(pwd)/toolchain/clang-${CLANG_VERSION}"

if [ -d "$CLANG_DIR/bin" ]; then
    log "Using cached toolchain at $CLANG_DIR (restored from CI cache or already present)"
else
    log "Fetching clang-${CLANG_VERSION}..."
    bash "${SCRIPT_DIR}/master.sh" clang "clang-${CLANG_VERSION}" "$CLANG_DIR"
fi

export PATH="${CLANG_DIR}/bin:${PATH}"

# CRITICAL: this kernel's top-level Makefile assigns CC/LD/AR/etc
export LLVM=1
export LLVM_IAS=1

export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

log "Toolchain ready: $(clang --version | head -1)"
