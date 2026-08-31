#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="${repo_root}/benchmarks/native/tbxbench.c"
output_file="${1:-${repo_root}/artifacts/tools/tbxbench-aarch64}"
compiler="${CROSS_COMPILE:-aarch64-linux-gnu-}gcc"

mkdir -p "$(dirname "${output_file}")"

"${compiler}" \
  -O2 \
  -pipe \
  -static \
  -pthread \
  -Wall \
  -Wextra \
  -Werror \
  -o "${output_file}" \
  "${source_file}"

file "${output_file}"
sha256sum "${output_file}"
