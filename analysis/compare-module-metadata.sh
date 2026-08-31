#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 STOCK_DIRECTORY REBUILT_DIRECTORY" >&2
    exit 2
fi

checked=0 differences=0
while IFS= read -r -d '' stock; do
    name=$(basename "$stock")
    rebuilt=$2/$name
    if [[ ! -f $rebuilt ]]; then
        echo "MISSING $name"
        ((differences += 1))
        continue
    fi

    for field in depends alias parm; do
        stock_meta=$(modinfo -F "$field" "$stock" | sort)
        rebuilt_meta=$(modinfo -F "$field" "$rebuilt" | sort)
        if [[ $stock_meta != "$rebuilt_meta" ]]; then
            printf 'DIFFERENT %s %s\n' "$name" "$field"
            diff -u <(printf '%s\n' "$stock_meta") \
                    <(printf '%s\n' "$rebuilt_meta") || true
            ((differences += 1))
        fi
    done
    ((checked += 1))
done < <(find "$1" -maxdepth 1 -type f -name '*.ko' -print0 | sort -z)

printf 'modules checked: %d\n' "$checked"
printf 'metadata differences: %d\n' "$differences"
[[ $differences -eq 0 ]]
