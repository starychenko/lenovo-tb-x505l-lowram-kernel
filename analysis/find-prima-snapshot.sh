#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
    echo "usage: $0 PRIMA_GIT_DIRECTORY BASE_COMMIT TIP_COMMIT [SOURCE_PATH]" >&2
    exit 2
fi

source_path=${4:-CORE/HDD/src/wlan_hdd_main.c}
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
printf '%-12s %-10s %-7s %-9s %-8s %-9s %s\n' \
    commit date memdump blacklist lowpower notify subject

{
    printf '%s\n' "$2"
    git -C "$1" rev-list --first-parent --reverse "$2..$3"
} | while read -r commit; do
    git -C "$1" show "$commit:$source_path" > "$tmp"
    date=$(git -C "$1" show -s --date=short --format=%ad "$commit")
    subject=$(git -C "$1" show -s --format=%s "$commit")
    memdump=0 blacklist=0 lowpower=0 notify=0
    grep -q 'memdump_init' "$tmp" && memdump=1
    git -C "$1" grep -q 'WDA_ProcessBlackListReq' "$commit" -- && blacklist=1
    git -C "$1" grep -q 'WDA_set_low_power_req' "$commit" -- && lowpower=1
    git -C "$1" grep -q 'WCTS_NotifyCallback' "$commit" -- && notify=1
    printf '%-12s %-10s %-7s %-9s %-8s %-9s %s\n' \
        "${commit:0:12}" "$date" "$memdump" "$blacklist" \
        "$lowpower" "$notify" "$subject"
done
