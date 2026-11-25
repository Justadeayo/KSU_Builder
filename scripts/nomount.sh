#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Integrates NoMount into the kernel tree in the current directory as a built-in driver.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/../config.env"

: "${NOMOUNT_REPO_URL:?NOMOUNT_REPO_URL not set — source config.env first}"
: "${NOMOUNT_TAG:?NOMOUNT_TAG not set — source config.env first}"

KDIR="$(pwd)"
NM_DIR="${KDIR}/NoMount"

rm -rf "$NM_DIR"
log "Cloning NoMount"
git clone --quiet "$NOMOUNT_REPO_URL" "$NM_DIR"

log "Running NoMount kernel setup at ${NOMOUNT_TAG}"
bash "${NM_DIR}/kernel/setup.sh" "$NOMOUNT_TAG"

[ -L "${KDIR}/fs/nomount" ] || die "fs/nomount symlink missing after NoMount setup"
grep -q 'obj-$(CONFIG_NOMOUNT) += nomount/' "${KDIR}/fs/Makefile" || die "NoMount line missing from fs/Makefile"
grep -q 'source "fs/nomount/Kconfig"' "${KDIR}/fs/Kconfig" || die "NoMount Kconfig not linked into fs/Kconfig (no endmenu in that file?)"
log "NoMount integrated at ${NOMOUNT_TAG}"
