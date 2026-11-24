#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Prints the manager certificate values the kernel build must trust, in the
# same form the manager signing check uses (see kernel/manager/apk_sign.c).
#
#   release-cert.sh <keystore> <alias> <store-password>
#
# Output (two lines, consumable with `while IFS='=' read -r k v`):
#   KSU_EXPECTED_SIZE=0x<4-hex-digit DER size>
#   KSU_EXPECTED_HASH=<sha256 of the DER certificate>
set -euo pipefail

KEYSTORE="${1:?usage: release-cert.sh <keystore> <alias> <store-password>}"
ALIAS="${2:?alias}"
STORE_PASS="${3:?store password}"

[ -f "$KEYSTORE" ] || { echo "keystore not found: $KEYSTORE" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
keytool -exportcert -alias "$ALIAS" -keystore "$KEYSTORE" -storepass "$STORE_PASS" -file "$TMP/cert.der" >/dev/null

SIZE_DEC="$(stat -c%s "$TMP/cert.der")"
printf 'KSU_EXPECTED_SIZE=0x%04x\n' "$SIZE_DEC"
printf 'KSU_EXPECTED_HASH=%s\n' "$(sha256sum "$TMP/cert.der" | awk '{print $1}')"
