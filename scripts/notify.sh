#!/usr/bin/env bash
set -uo pipefail

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN:-}"

enabled() {
    [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]
}

send_text() {
    enabled || return 0
    curl -sf -X POST "$API/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "parse_mode=Markdown" \
        -d "disable_web_page_preview=true" \
        --data-urlencode "text=$1" >/dev/null && return 0
    curl -sf -X POST "$API/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "disable_web_page_preview=true" \
        --data-urlencode "text=$1" >/dev/null || echo "::warning::Telegram message not sent" >&2
    return 0
}

send_doc() {
    enabled || return 0
    curl -sf -X POST "$API/sendDocument" \
        -F "chat_id=${TELEGRAM_CHAT_ID}" \
        -F "caption=$2" \
        -F "document=@$1" >/dev/null && return 0
    echo "::warning::Telegram file not sent: $1" >&2
    return 1
}

fmt_time() {
    TZ=Africa/Lagos date -d "@$1" '+%d %b %Y, %H:%M WAT'
}

fmt_dur() {
    printf '%dm %ds' $(( $1 / 60 )) $(( $1 % 60 ))
}

case "${1:-}" in
    sync)
        synced="$2"; sha="$3"; when="$4"; subject="${5//\`/}"
        send_text "🔄 *KernelSU Sync*

*Synced*: ${synced}
*Commit*: \`${sha}\`
*Message*: \`${subject}\`
*Upstream commit date*: ${when}"
        ;;
    start)
        device="$2"; kernel="$3"; root="$4"; compiler="$5"
        now=$(date +%s)
        send_text "🛠 *${kernel} Kernel Build Started!*

*Device*: \`${device}\`
*Root*: \`${root}\`
*Compiler*: \`${compiler}\`
*Started at*: $(fmt_time "$now")
*Status*: Compilation in progress..."
        echo "$now"
        ;;
    finish)
        device="$2"; kernel="$3"; compiler="$4"; started="${5:-$(date +%s)}"
        shift 5
        now=$(date +%s)
        shopt -s nullglob
        lines=""
        files=()
        for arg in "$@"; do
            pattern="${arg%:*}"
            label="${arg##*:}"
            for f in $pattern; do
                [ -f "$f" ] || continue
                size=$(du -h "$f" | cut -f1)
                lines+="*${label}*: \`$(basename "$f")\` (${size})"$'\n'
                files+=("$f:$label")
            done
        done
        if [ "${#files[@]}" -eq 0 ]; then
            echo "::warning::No build outputs found, nothing to send." >&2
            exit 0
        fi
        # Upload every file before the summary, so "Finished Successfully" is only
        # sent once all artifacts have reached Telegram.
        failed=0
        for entry in "${files[@]}"; do
            send_doc "${entry%:*}" "${entry##*:}" || failed=1
        done
        if [ "$failed" -eq 0 ]; then
            send_text "✅ *${kernel} Build Finished Successfully!*

*Device*: \`${device}\`
*Compiler*: \`${compiler}\`
*Compilation Time*: $(fmt_dur $((now - started)))
*Finished at*: $(fmt_time "$now")

${lines}"
        else
            send_text "⚠️ *${kernel} Build Finished, but some files failed to upload to Telegram.*

*Device*: \`${device}\`
*Compiler*: \`${compiler}\`
*Finished at*: $(fmt_time "$now")

${lines}Check the workflow run for the files."
            exit 1
        fi
        ;;
    *)
        echo "usage: notify.sh sync <yes|no> <short-sha> <commit-date> <commit-subject>" >&2
        echo "       notify.sh start <device> <kernel> <root> <compiler>" >&2
        echo "       notify.sh finish <device> <kernel> <compiler> <start-epoch> <path:label>..." >&2
        exit 2
        ;;
esac
