#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 MODULE_SYMVERS MODULE_DIRECTORY" >&2
    exit 2
fi

declare -A kernel_crc
while read -r crc symbol provider export_type; do
    if [[ $provider == vmlinux ]]; then
        kernel_crc[$symbol]=${crc,,}
    fi
done < "$1"

total=0 exact=0 mismatch=0 unresolved=0
while IFS= read -r -d '' module; do
    while read -r module_crc symbol; do
        [[ -n ${symbol:-} ]] || continue
        ((total += 1))
        if [[ -v "kernel_crc[$symbol]" ]]; then
            if [[ ${module_crc,,} == "${kernel_crc[$symbol]}" ]]; then
                ((exact += 1))
            else
                ((mismatch += 1))
                printf 'MISMATCH\t%s\t%s\t%s\t%s\n' \
                    "$(basename "$module")" "$symbol" "$module_crc" \
                    "${kernel_crc[$symbol]}"
            fi
        else
            ((unresolved += 1))
        fi
    done < <(modprobe --show-modversions "$module")
done < <(find "$2" -type f -name '*.ko' -print0 | sort -z)

printf 'vmlinux imports checked: %d\n' "$total"
printf 'exact CRC matches:      %d\n' "$exact"
printf 'CRC mismatches:         %d\n' "$mismatch"
printf 'non-vmlinux imports:    %d\n' "$unresolved"
[[ $mismatch -eq 0 ]]
