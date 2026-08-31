#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "usage: $0 KERNEL_GIT_DIRECTORY [TAG_PATTERN]" >&2
    exit 2
fi

pattern=${2:-LA.UM.8.6.2*}
while IFS= read -r tag; do
    sublevel=$(git -C "$1" show "$tag:Makefile" 2>/dev/null | \
        awk '$1 == "SUBLEVEL" { print $3; exit }')
    [[ -n $sublevel ]] && printf '%s\t4.9.%s\n' "$tag" "$sublevel"
done < <(git -C "$1" tag -l "$pattern" | sort -V)
