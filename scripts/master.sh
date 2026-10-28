#!/usr/bin/env bash
# scripts/master.sh
#
# One place for the steps every KSU_Builder workflow repeats:
# build dependencies, the AOSP Clang toolchain, Telegram messages and
# AnyKernel3 packaging. Workflows call this file instead of carrying
# their own copy.
#
# Usage (from the repository root, after checkout):
#   bash scripts/master.sh deps
#   bash scripts/master.sh clang <clang-version> [dest-dir]
#   bash scripts/master.sh tg-msg "<markdown text>"
#   bash scripts/master.sh tg-doc <file> "<markdown caption>"
#   bash scripts/master.sh ksu-setup <kernel-dir> <ksu-type> <defconfig> <setup-url>
#   bash scripts/master.sh compile <clang-version> <defconfig-target> <kernel-dir> <log-file>
#   bash scripts/master.sh fail-report <log-file> <device> <label> <start-epoch>
#   bash scripts/master.sh prune-ccache <cache-key>
#   bash scripts/master.sh anykernel <boot-dir> <kernel-name> <device> <label> <clang-bin-dir>
#       label: KernelSU, ReSukiSU, or None/NoKSU (no root). Prints the zip name on stdout.
#
# Environment used by the Telegram and AnyKernel3 commands:
#   TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID  optional; if unset, Telegram steps are skipped
#   AK3_REPO, AK3_BRANCH                  optional; default Justadeayo/AnyKernel3 master
#
# Failures in Telegram delivery never fail a build.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

AK3_REPO="${AK3_REPO:-https://github.com/Justadeayo/AnyKernel3.git}"
AK3_BRANCH="${AK3_BRANCH:-master}"
ANDROID_SRC="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs"

# ---------------------------------------------------------------- deps
cmd_deps() {
    sudo rm -rf /etc/apt/sources.list.d/* || true
    sudo apt-get -o Acquire::Timeout=5 -o Acquire::Retries=0 update
    sudo apt-get install -y --no-install-recommends \
        bc bison flex cpio dwarves zip rsync jq ccache \
        build-essential git python3 curl lz4 lld \
        libssl-dev libelf-dev libdw-dev \
        gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi
}

# ---------------------------------------------------------------- clang
# Clang versions live on different googlesource refs. Try them in order and
# keep the first one that downloads. clang-r416183b comes from LineageOS.
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
        local ref tarball="${ver}.tar.gz" found=0
        for ref in "heads/main-kernel" "tags/android-14.0.0_r33" \
                   "heads/android16-qpr2-release" "heads/main"; do
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

# ---------------------------------------------------------------- telegram
tg_enabled() {
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
        log "Telegram secrets not set, skipping Telegram step."
        return 1
    fi
}

# Telegram rejects Markdown it can't parse (an unpaired "_" in a repo name,
# for example), so every send retries once as plain text.
cmd_tg_msg() {
    local text="${1:?usage: tg-msg \"<text>\"}"
    tg_enabled || return 0
    local url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    if ! curl -sf -X POST "$url" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "parse_mode=Markdown" \
            -d "disable_web_page_preview=true" \
            --data-urlencode "text=${text}" >/dev/null; then
        warn "Markdown rejected, resending as plain text."
        curl -sf -X POST "$url" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "disable_web_page_preview=true" \
            --data-urlencode "text=${text}" >/dev/null || warn "Telegram message failed (not fatal)."
    fi
}

cmd_tg_doc() {
    local file="${1:?usage: tg-doc <file> \"<caption>\">}"
    local caption="${2:-}"
    tg_enabled || return 0
    [ -f "$file" ] || { warn "tg-doc: ${file} not found, sending text instead."; cmd_tg_msg "$caption"; return 0; }
    local url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument"
    if ! curl -sf -X POST "$url" \
            -F "chat_id=${TELEGRAM_CHAT_ID}" \
            -F "parse_mode=Markdown" \
            --form-string "caption=${caption}" \
            -F "document=@${file}" >/dev/null; then
        warn "Markdown caption rejected, resending without formatting."
        curl -sf -X POST "$url" \
            -F "chat_id=${TELEGRAM_CHAT_ID}" \
            --form-string "caption=${caption}" \
            -F "document=@${file}" >/dev/null || warn "Telegram document failed (not fatal)."
    fi
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
        None|NoKSU|nsu) ks_flag=false ;;
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
# Runs a KernelSU-family setup.sh inside the kernel tree and appends the
# options that root needs to the defconfig.
#   ksu-setup <kernel-dir> <ksu-type> <defconfig-rel-path> <setup-url>
# ksu-type: None (does nothing), KernelSU, ReSukiSU.
cmd_ksu_setup() {
    local kdir="${1:?usage: ksu-setup <kernel-dir> <ksu-type> <defconfig> <setup-url>}"
    local ksu_type="${2:?ksu-type}" defconfig="${3:?defconfig path}" url="${4:?setup.sh url}"

    [ "$ksu_type" = "None" ] && { log "ksu-type None, skipping KernelSU setup."; return 0; }

    cd "$kdir"
    curl -LSs "$url" > setup.sh
    sed -i 's|backslashxx/KernelSU|Justadeayo/KernelSU|g' setup.sh
    bash setup.sh master

    {
        echo "CONFIG_KSU=y"
        echo "CONFIG_KPROBES=y"
        echo "CONFIG_KPROBE_EVENTS=y"
        echo "CONFIG_KSU_KPROBE_HOOKS=y"
        echo "CONFIG_OVERLAY_FS=y"
        echo "CONFIG_KSU_TAMPER_SYSCALL_TABLE=y"
        [ "$ksu_type" = "ReSukiSU" ] && echo "CONFIG_KSU_SUSFS=y"
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

# ---------------------------------------------------------------- fail-report
# Sends a failure message with the tail of the build log attached.
#   fail-report <log-file> <device> <variant-label> <start-epoch>
cmd_fail_report() {
    local logf="${1:?usage: fail-report <log> <device> <label> <start-epoch>}"
    local device="${2:-?}" label="${3:-?}" start="${4:-0}"
    local now dur mins secs msg
    now=$(date +%s)
    dur=$(( start > 0 ? now - start : 0 ))
    mins=$(( dur / 60 )); secs=$(( dur % 60 ))

    msg="*Build Failed!* ❌

*Device*: \`${device}\`
*Variant*: \`${label}\`
*Duration*: \`${mins}m ${secs}s\`
*Run Link*: https://github.com/${GITHUB_REPOSITORY:-unknown}/actions/runs/${GITHUB_RUN_ID:-0}"

    if [ -f "$logf" ]; then
        local preview="${RUNNER_TEMP:-/tmp}/error_preview.txt" zipf="${RUNNER_TEMP:-/tmp}/error_logs.zip"
        tail -n 35 "$logf" > "$preview"
        rm -f "$zipf"
        zip -j "$zipf" "$logf" "$preview" >/dev/null
        cmd_tg_doc "$zipf" "$msg"
    else
        cmd_tg_msg "$msg"
    fi
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
    deps)      shift; cmd_deps "$@" ;;
    clang)     shift; cmd_clang "$@" ;;
    tg-msg)    shift; cmd_tg_msg "$@" ;;
    tg-doc)    shift; cmd_tg_doc "$@" ;;
    anykernel) shift; cmd_anykernel "$@" ;;
    ksu-setup) shift; cmd_ksu_setup "$@" ;;
    compile)   shift; cmd_compile "$@" ;;
    fail-report) shift; cmd_fail_report "$@" ;;
    prune-ccache) shift; cmd_prune_ccache "$@" ;;
    ""|-h|--help|help)
        sed -n '2,20p' "${BASH_SOURCE[0]}" ;;
    *) die "unknown command: $1 (see: bash scripts/master.sh help)" ;;
esac
