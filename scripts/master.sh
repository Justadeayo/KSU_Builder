#!/usr/bin/env bash
# scripts/master.sh
#
# One place for the steps every KSU_Builder workflow repeats:
# the AOSP Clang toolchain, ccache pruning and AnyKernel3 packaging. Telegram messages live in scripts/notify.sh. Workflows call this file instead of carrying their own copy.
#
# Usage (from the repository root, after checkout):
#   bash scripts/master.sh clang <clang-version> [dest-dir]
#   bash scripts/master.sh ksu-setup <kernel-dir> <ksu-type> <defconfig> [susfs: true|false]
#   bash scripts/master.sh compile <clang-version> <defconfig-target> <kernel-dir> <log-file>
#   bash scripts/master.sh prune-ccache <cache-key>
#   bash scripts/master.sh anykernel <boot-dir> <kernel-name> <device> <label> <clang-bin-dir>
#       label: KernelSU, or None/NonKSU (no root). Prints the zip name on stdout.
#
#   AK3_REPO, AK3_BRANCH                  optional; default Justadeayo/AnyKernel3 master
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

AK3_REPO="${AK3_REPO:-https://github.com/Justadeayo/AnyKernel3.git}"
AK3_BRANCH="${AK3_BRANCH:-master}"
ANDROID_SRC="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs"

# ---------------------------------------------------------------- clang
# Clang versions live on different googlesource refs. Try them in order and
# keep the first one that downloads. clang-r416183b comes from LineageOS.
# Preferred googlesource ref per Clang version, tried first. Versions not listed here go straight through DEFAULT_REFS.
declare -A CLANG_REF=(
    [clang-r596125]="heads/main-kernel"
    [clang-r614150]="heads/main-kernel"
    [clang-r584948]="heads/main-kernel"
)

# Fallback chain, tried in order for every version.
DEFAULT_REFS=(
    "heads/main-kernel"
    "tags/android-14.0.0_r33"
    "heads/android16-qpr2-release"
    "heads/main"
)

cmd_clang() {
    local ver="${1:?usage: clang <clang-version> [dest-dir]}"
    local dest="${2:-toolchains/${ver}}"

    if [ -x "${dest}/bin/clang" ]; then
        log "clang ${ver} already present at ${dest}"
        return 0
    fi

    rm -rf "$dest"
    mkdir -p "$dest"

    if [ "$ver" = "clang-r416183b" ]; then
        git clone --depth=1 \
            https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b.git \
            "$dest"
    else
        local refs=("${DEFAULT_REFS[@]}")
        if [ -n "${CLANG_REF[$ver]:-}" ]; then
            refs=("${CLANG_REF[$ver]}" "${DEFAULT_REFS[@]}")
        fi
        local ref tarball="${ver}.tar.gz" found=0
        for ref in "${refs[@]}"; do
            log "trying ${ref} for ${ver}"
            if curl -fL --retry 8 --retry-delay 20 --retry-all-errors \
                    --connect-timeout 30 -o "$tarball" "${ANDROID_SRC}/${ref}/${ver}.tar.gz"; then
                tar -xf "$tarball" -C "$dest"
                rm -f "$tarball"
                found=1
                break
            fi
        done
        [ "$found" -eq 1 ] || die "could not download ${ver} from any known googlesource ref"
    fi

    [ -x "${dest}/bin/clang" ] || die "clang binary missing after fetching ${ver}"
    log "clang ${ver} ready at ${dest}"
}

# ---------------------------------------------------------------- anykernel
# Packages Image/dtb/dtbo from a kernel build into an AnyKernel3 flashable zip.
# Writes the zip into the current directory and prints its name.
cmd_anykernel() {
    local boot_dir="${1:?usage: anykernel <boot-dir> <kernel-name> <device> <label> <clang-bin>}"
    local kname="${2:?kernel name}" device="${3:?device}" label="${4:?label, e.g. KernelSU or None}" clang_bin="${5:?clang bin dir}"
    local ks_flag clang_ver build_date zip_name work

    # Labels that mean "no root" keep ksu_supported=false.
    case "$label" in
        None|NonKSU|nsu) ks_flag=false ;;
        *)              ks_flag=true ;;
    esac

    zip_name="${kname}_${device}_${label// /_}_$(date +%Y%m%d_%H%M)"
    work="ak3_${device}_${label// /_}"
    rm -rf "$work"
    git clone --depth=1 -b "$AK3_BRANCH" "$AK3_REPO" "$work" >&2

    [ -f "${boot_dir}/Image.gz" ]     && cp "${boot_dir}/Image.gz" "$work/Image.gz"
    [ -f "${boot_dir}/Image.gz-dtb" ] && cp "${boot_dir}/Image.gz-dtb" "$work/Image.gz-dtb"
    [ -f "${boot_dir}/dtb.img" ]      && cp "${boot_dir}/dtb.img" "$work/dtb"
    [ -f "${boot_dir}/dtb" ]          && cp "${boot_dir}/dtb" "$work/dtb"
    [ -f "${boot_dir}/dtbo.img" ]     && cp "${boot_dir}/dtbo.img" "$work/dtbo.img"

    ls "$work"/Image.gz* >/dev/null 2>&1 || die "no Image.gz or Image.gz-dtb in ${boot_dir}"

    clang_ver=$("${clang_bin}/clang" --version | head -n1 | sed 's/(https.*//; s/ version//' | xargs)
    build_date=$(date +'%Y-%m-%d %H:%M WAT')

    sed -i "s/device.name1=.*/device.name1=${device}/" "$work/anykernel.sh"
    sed -i "s|ksu_supported=false|ksu_supported=${ks_flag}|" "$work/anykernel.sh"
    sed -i "s|##CLANG_VERSION##|${clang_ver}|" "$work/anykernel.sh"
    sed -i "s|##BUILD_DATE##|${build_date}|" "$work/anykernel.sh"

    (cd "$work" && zip -r9 "../${zip_name}.zip" * -x .git >/dev/null)
    rm -rf "$work"
    log "packaged ${zip_name}.zip" >&2
    # stdout carries only the zip name, so callers can capture it with $(...)
    echo "${zip_name}.zip"
}

# ---------------------------------------------------------------- ksu-setup
# susfs_apply <kernel-dir> <defconfig> <script-dir>
susfs_apply() {
    local kdir="$1" defconfig="$2" script_dir="$3"
    local kver device
    kver="$(sed -n 's/^VERSION = //p;s/^PATCHLEVEL = //p' "$kdir/Makefile" | paste -sd. -)"
    device="$(basename "$defconfig" _defconfig)"
    bash "${script_dir}/susfs-setup.sh" "$kdir" "$kver" "$device"
}

# ksu-setup <kernel-dir> <ksu-type> <defconfig> [susfs: true|false]
cmd_ksu_setup() {
    local kdir="${1:?usage: ksu-setup <kernel-dir> <ksu-type> <defconfig> [susfs: true|false]}"
    local ksu_type="${2:?ksu-type}" defconfig="${3:?defconfig path}"
    local susfs="${4:-true}"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [ -f "${script_dir}/../config.env" ] && source "${script_dir}/../config.env"

    [ "$ksu_type" = "None" ] && { log "ksu-type None, skipping KernelSU setup."; return 0; }

    case "$ksu_type" in
        KernelSU)
            bash "${script_dir}/ksu-fetch.sh" "$kdir"
            if [ "$susfs" = "true" ]; then
                susfs_apply "$kdir" "$defconfig" "$script_dir"
            fi
            ;;
        *) die "unknown ksu-type: $ksu_type" ;;
    esac

    cd "$kdir"
    NM_ON=false
    if [ -n "${NOMOUNT_TAG:-}" ] && [ "${NOMOUNT_ENABLED:-true}" = "true" ] && [ "$ksu_type" = "KernelSU" ]; then
        NM_ON=true
        bash "${script_dir}/nomount.sh"
    fi
    {
        echo "CONFIG_KSU=y"
        echo "CONFIG_KPROBES=y"
        echo "CONFIG_KPROBE_EVENTS=y"
        echo "CONFIG_KSU_KPROBE_HOOKS=y"
        echo "CONFIG_OVERLAY_FS=y"
        # Needed for the KernelSU driver to get root on this kernel
        [ "$ksu_type" = "KernelSU" ] && echo "CONFIG_KSU_TAMPER_SYSCALL_TABLE=y"
        if [ "$ksu_type" = "KernelSU" ] && [ "$susfs" = "true" ]; then
            for opt in CONFIG_KSU_SUSFS CONFIG_KSU_SUSFS_SUS_PATH CONFIG_KSU_SUSFS_SUS_MOUNT \
                       CONFIG_KSU_SUSFS_SUS_KSTAT CONFIG_KSU_SUSFS_SPOOF_UNAME CONFIG_KSU_SUSFS_ENABLE_LOG \
                       CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
                       CONFIG_KSU_SUSFS_OPEN_REDIRECT CONFIG_KSU_SUSFS_SUS_MAP; do
                echo "${opt}=y"
            done
        fi
        if [ "$NM_ON" = "true" ]; then
            echo "CONFIG_NOMOUNT=y"
        fi
    } >> "$defconfig"
    cd - >/dev/null
    log "KernelSU (${ksu_type}) configured in ${defconfig}"
}

# ---------------------------------------------------------------- compile
# Builds the kernel with ccache and the pinned Clang.
#   compile <clang-version> <defconfig-target> <kernel-dir> <log-file>
# Set REQUIRE_KSU_TAMPER=true to fail when the final .config lost
# CONFIG_KSU_TAMPER_SYSCALL_TABLE.
cmd_compile() {
    local ver="${1:?usage: compile <clang-version> <defconfig> <kernel-dir> <log-file>}"
    local target="${2:?defconfig target}" kdir="${3:?kernel dir}" logf="${4:?log file}"
    local root="${GITHUB_WORKSPACE:-$PWD}"
    local clang_bin="${root}/toolchains/${ver}/bin"
    [ -x "${clang_bin}/clang" ] || die "clang not found at ${clang_bin}; run: master.sh clang ${ver}"

    export PATH="/usr/lib/ccache:${clang_bin}:$PATH"
    export CCACHE_COMPILERCHECK="string:${ver}"
    export CC="ccache ${clang_bin}/clang"
    export CXX="ccache ${clang_bin}/clang++"
    export HOSTCC="ccache ${clang_bin}/clang"
    export HOSTCXX="ccache ${clang_bin}/clang++"
    export ARCH=arm64 SUBARCH=arm64 LLVM=1 LLVM_IAS=1
    export LD="${clang_bin}/ld.lld" AR="${clang_bin}/llvm-ar" NM="${clang_bin}/llvm-nm"
    export OBJCOPY="${clang_bin}/llvm-objcopy" OBJDUMP="${clang_bin}/llvm-objdump" STRIP="${clang_bin}/llvm-strip"
    export CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-

    cd "$kdir"
    mkdir -p out
    touch ./.scmversion
    make O=out "$target" CLANG_TRIPLE=aarch64-linux-gnu-
    make O=out olddefconfig CLANG_TRIPLE=aarch64-linux-gnu-

    if grep -q "^CONFIG_KSU_SUSFS=y" out/.config; then
        cur="$(sed -n 's/^CONFIG_LOCALVERSION="\(.*\)"$/\1/p' out/.config)"
        if [[ "$cur" != *-susfs ]]; then
            ./scripts/config --file out/.config --set-str CONFIG_LOCALVERSION "${cur}-susfs"
            log "LOCALVERSION: appended -susfs (${cur}-susfs)"
        fi
    fi

    if [ "${REQUIRE_KSU_TAMPER:-false}" = "true" ] && ! grep -q "^CONFIG_KSU_TAMPER_SYSCALL_TABLE=y" out/.config; then
        die "CONFIG_KSU_TAMPER_SYSCALL_TABLE is not enabled in the final .config. Root would fail."
    fi

    set +e
    make -j"$(nproc)" O=out CLANG_TRIPLE=aarch64-linux-gnu- 2>&1 | tee "$logf"
    local status=${PIPESTATUS[0]}
    set -e
    [ "$status" -eq 0 ] || die "kernel compilation failed (see ${logf})"
    log "kernel built"
}

# ---------------------------------------------------------------- prune-ccache
# Keeps the newest ccache entry for a key and deletes the rest.
#   prune-ccache <cache-key-prefix>
cmd_prune_ccache() {
    local key="${1:?usage: prune-ccache <key>}"
    : "${GITHUB_REPOSITORY:?}" "${GITHUB_REF:?}"
    gh cache list --repo "$GITHUB_REPOSITORY" --ref "$GITHUB_REF" --key "$key" \
        --sort created_at --order desc --limit 100 --json id \
        | jq -r '.[1:][].id' \
        | xargs -r -I{} gh cache delete {} --repo "$GITHUB_REPOSITORY" || true
}

case "${1:-}" in
    clang)     shift; cmd_clang "$@" ;;
    anykernel) shift; cmd_anykernel "$@" ;;
    ksu-setup) shift; cmd_ksu_setup "$@" ;;
    compile)   shift; cmd_compile "$@" ;;
    prune-ccache) shift; cmd_prune_ccache "$@" ;;
    ""|-h|--help|help)
        sed -n '2,20p' "${BASH_SOURCE[0]}" ;;
    *) die "unknown command: $1 (see: bash scripts/master.sh help)" ;;
esac
