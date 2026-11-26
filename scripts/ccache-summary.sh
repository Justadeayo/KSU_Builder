#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Shared ccache helper for the build workflows.
#
#   ccache-summary.sh reset   zero the counters, so the next report covers one run
#   ccache-summary.sh report  print ccache -s to the log and add a CCache Statistics table to the job summary
#
# Uses CCACHE_DIR if set, otherwise $HOME/.ccache. Skips quietly if ccache is missing.
set -uo pipefail

export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

case "${1:-}" in
    reset)
        command -v ccache >/dev/null && ccache --zero-stats >/dev/null 2>&1 || true
        ;;
    report)
        if ! command -v ccache >/dev/null; then
            echo "ccache not installed, skipping summary." | tee -a "$SUMMARY"
            exit 0
        fi

        ccache -s || true

        STATS=$(ccache --print-stats 2>/dev/null || true)
        HITS=$(awk -F'\t' '$1=="direct_cache_hit" || $1=="preprocessed_cache_hit" {s+=$2} END {print s+0}' <<<"$STATS")
        MISSES=$(awk -F'\t' '$1=="cache_miss" {s+=$2} END {print s+0}' <<<"$STATS")
        TOTAL=$((HITS + MISSES))

        RATE="0.0"
        if [ "$TOTAL" -gt 0 ]; then
            RATE=$(awk -v h="$HITS" -v t="$TOTAL" 'BEGIN {printf "%.1f", h * 100 / t}')
        fi

        {
            echo "## CCache Statistics"
            echo ""
            echo "| Cache hits | ${HITS} / ${TOTAL} | ${RATE}% |"
            echo "| :--- | :--- | :--- |"
        } >> "$SUMMARY"
        ;;
    *)
        echo "usage: ccache-summary.sh reset|report" >&2
        exit 2
        ;;
esac
