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
        -F "document=@$1" >/dev/null || echo "::warning::Telegram file not sent: $1" >&2
    return 0
}

fmt_time() {
    TZ=Africa/Lagos date -d "@$1" '+%d %b %Y, %H:%M WAT'
}

fmt_dur() {
    printf '%dm %ds' $(( $1 / 60 )) $(( $1 % 60 ))
}

case "${1:-}" in
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
        send_text "✅ *${kernel} Build Finished Successfully!*

*Device*: \`${device}\`
*Compiler*: \`${compiler}\`
*Compilation Time*: $(fmt_dur $((now - started)))
*Finished at*: $(fmt_time "$now")

${lines}"
        for entry in "${files[@]}"; do
            send_doc "${entry%:*}" "${entry##*:}"
        done
        ;;
    *)
        echo "usage: notify.sh start <device> <kernel> <root> <compiler>" >&2
        echo "       notify.sh finish <device> <kernel> <compiler> <start-epoch> <path:label>..." >&2
        exit 2
        ;;
esac
