#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 STOCK_DIRECTORY REBUILT_DIRECTORY" >&2
    exit 2
fi

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
printf 'file\tstock_def\trebuilt_def\tstock_def_only\trebuilt_def_only\tstock_import\trebuilt_import\tstock_import_only\trebuilt_import_only\n'

while IFS= read -r -d '' stock; do
    name=$(basename "$stock")
    rebuilt=$2/$name
    test -f "$rebuilt"
    nm -g --defined-only "$stock" | sed 's/.* //' | sort -u > "$tmp/stock-def"
    nm -g --defined-only "$rebuilt" | sed 's/.* //' | sort -u > "$tmp/rebuilt-def"
    modprobe --show-modversions "$stock" | sed 's/.*[[:space:]]//' | sort -u > "$tmp/stock-import"
    modprobe --show-modversions "$rebuilt" | sed 's/.*[[:space:]]//' | sort -u > "$tmp/rebuilt-import"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$name" \
        "$(wc -l < "$tmp/stock-def")" "$(wc -l < "$tmp/rebuilt-def")" \
        "$(comm -23 "$tmp/stock-def" "$tmp/rebuilt-def" | wc -l)" \
        "$(comm -13 "$tmp/stock-def" "$tmp/rebuilt-def" | wc -l)" \
        "$(wc -l < "$tmp/stock-import")" "$(wc -l < "$tmp/rebuilt-import")" \
        "$(comm -23 "$tmp/stock-import" "$tmp/rebuilt-import" | wc -l)" \
        "$(comm -13 "$tmp/stock-import" "$tmp/rebuilt-import" | wc -l)"
done < <(find "$1" -maxdepth 1 -type f -name '*.ko' -print0 | sort -z)
