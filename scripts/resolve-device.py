#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Based on Zincore Forge by yureixen (https://github.com/yureixen/zincore-forge).
# Copied and modified for Justadeayo/KSU_Builder. Licensed under GPL-2.0; see LICENSE-GPL-2.0.
#
# Resolves the device config for build.yml: devices/<device>.json with every
# non-empty workflow input applied on top. Empty inputs keep the JSON value.
#
#   DEVICE=violet IN_KERNEL_NAME=... python3 scripts/resolve-device.py <devices-dir>
#
# Prints the resolved config as one line of JSON on stdout. Log lines go to stderr,
# so the caller can capture stdout directly.
import json
import os
import sys

dev = os.environ["DEVICE"]
devices_dir = sys.argv[1] if len(sys.argv) > 1 else "builder/devices"
path = os.path.join(devices_dir, f"{dev}.json")

if not os.path.isfile(path):
    raise SystemExit(f"::error::No device config at {path}. Add it or leave device_codename empty.")

cfg = json.load(open(path))[dev]
cfg["device"] = dev

# JSON key -> environment variable carrying the matching workflow input.
overrides = {
    "kernel_name":    "IN_KERNEL_NAME",
    "kernel_repo":    "IN_KERNEL_REPO",
    "kernel_branch":  "IN_KERNEL_BRANCH",
    "kernel_version": "IN_KERNEL_VERSION",
    "defconfig":      "IN_DEFCONFIG",
    "clang_version":  "IN_CLANG_VERSION",
    "ak3_repo":       "IN_AK3_REPO",
    "ak3_branch":     "IN_AK3_BRANCH",
}

applied = []
for key, env_name in overrides.items():
    value = os.environ.get(env_name, "").strip()
    if value == "default":
        value = ""
    if value:
        cfg[key] = value
        applied.append(key)

print(f"Device: {dev}", file=sys.stderr)
print("Inputs applied over JSON: " + (", ".join(applied) if applied else "none"), file=sys.stderr)
print(json.dumps(cfg, separators=(",", ":")))
