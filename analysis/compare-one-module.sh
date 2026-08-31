#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 STOCK_MODULE REBUILT_MODULE" >&2
    exit 2
fi

echo '=== stock modinfo ==='
modinfo "$1" | sed -n '1,20p'
echo '=== rebuilt modinfo ==='
modinfo "$2" | sed -n '1,20p'
echo '=== SHA-256 and size ==='
sha256sum "$1" "$2"
stat -c '%s %n' "$1" "$2"
echo '=== imported symbol counts ==='
printf 'stock:   '; modprobe --show-modversions "$1" | wc -l
printf 'rebuilt: '; modprobe --show-modversions "$2" | wc -l
echo '=== imported symbol set differences ==='
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
modprobe --show-modversions "$1" | awk '{print $2}' | sort -u > "$tmp/stock"
modprobe --show-modversions "$2" | awk '{print $2}' | sort -u > "$tmp/rebuilt"
comm -23 "$tmp/stock" "$tmp/rebuilt" | sed 's/^/< stock-only:   /'
comm -13 "$tmp/stock" "$tmp/rebuilt" | sed 's/^/> rebuilt-only: /'
