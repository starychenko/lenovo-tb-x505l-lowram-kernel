#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <kernel-source> <clang-r365631c-dir> <aarch64-gcc-4.9-dir> <config> <output-dir> [reproducibility-key.pem]" >&2
}

if [[ $# -lt 5 || $# -gt 6 ]]; then
    usage
    exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "${script_dir}/.." && pwd)"
kernel_source="$(realpath "$1")"
clang_dir="$(realpath "$2")"
gcc_dir="$(realpath "$3")"
config_source="$(realpath "$4")"
output_dir="$5"
reproducibility_key="${6:-}"
build_timestamp="${TB_X505L_BUILD_TIMESTAMP:-Mon Aug 31 08:00:00 UTC 2026}"
build_version="${TB_X505L_BUILD_VERSION:-6}"

if [[ ! -f "${kernel_source}/Makefile" ]]; then
    echo "Kernel Makefile not found in ${kernel_source}" >&2
    exit 1
fi

if [[ ! -x "${clang_dir}/bin/clang" ]]; then
    echo "Clang executable not found in ${clang_dir}/bin" >&2
    exit 1
fi

if [[ ! -x "${gcc_dir}/bin/aarch64-linux-android-gcc" ]]; then
    echo "AArch64 GCC 4.9 toolchain not found in ${gcc_dir}/bin" >&2
    exit 1
fi

if [[ ! -f "${config_source}" ]]; then
    echo "Candidate config not found: ${config_source}" >&2
    exit 1
fi

if ! grep -q 'tb_x505l_vendor_module' "${kernel_source}/kernel/module.c"; then
    echo "The r5 source patch is not applied to ${kernel_source}" >&2
    exit 1
fi

if ! grep -q '^CONFIG_LOCALVERSION="-tbx505l-r6' "${config_source}"; then
    echo "Refusing a config without an explicit TB-X505L r6 local version." >&2
    exit 1
fi

if [[ -d "${output_dir}" ]] && find "${output_dir}" -mindepth 1 -print -quit | grep -q .; then
    if [[ "${TB_X505L_ALLOW_DIRTY_OUT:-0}" != "1" ]]; then
        echo "Output directory is not empty: ${output_dir}" >&2
        echo "Use a fresh directory, or set TB_X505L_ALLOW_DIRTY_OUT=1 deliberately." >&2
        exit 1
    fi
fi

mkdir -p "${output_dir}"
output_dir="$(realpath "${output_dir}")"
cp "${config_source}" "${output_dir}/.config"

if [[ -n "${reproducibility_key}" ]]; then
    reproducibility_key="$(realpath "${reproducibility_key}")"
    if [[ ! -f "${reproducibility_key}" ]]; then
        echo "Reproducibility key not found: ${reproducibility_key}" >&2
        exit 1
    fi
    mkdir -p "${output_dir}/certs"
    install -m 0644 "${project_dir}/reproducibility/x509.genkey" "${output_dir}/certs/x509.genkey"
    install -m 0600 "${reproducibility_key}" "${output_dir}/certs/signing_key.pem"
fi

echo "Kernel source: ${kernel_source}"
git -C "${kernel_source}" log -1 --oneline
echo "Compiler:"
"${clang_dir}/bin/clang" --version | head -n 1
echo "Input config:"
sha256sum "${config_source}"
echo "Build identity: version=${build_version}, timestamp=${build_timestamp}"

make_args=(
    -C "${kernel_source}"
    O="${output_dir}"
    ARCH=arm64
    SUBARCH=arm64
    LOCALVERSION=+
    HOSTCFLAGS=-fcommon
    CC="${clang_dir}/bin/clang"
    CLANG_TRIPLE=aarch64-linux-gnu-
    CROSS_COMPILE="${gcc_dir}/bin/aarch64-linux-android-"
)

env \
    KBUILD_BUILD_USER=codex-r6 \
    KBUILD_BUILD_HOST=tb-x505l \
    KBUILD_BUILD_VERSION="${build_version}" \
    KBUILD_BUILD_TIMESTAMP="${build_timestamp}" \
    make "${make_args[@]}" usr/

env \
    KBUILD_BUILD_USER=codex-r6 \
    KBUILD_BUILD_HOST=tb-x505l \
    KBUILD_BUILD_VERSION="${build_version}" \
    KBUILD_BUILD_TIMESTAMP="${build_timestamp}" \
    make "${make_args[@]}" \
    -j"$(nproc)" \
    Image

image_path="${output_dir}/arch/arm64/boot/Image"
if [[ ! -f "${image_path}" ]]; then
    echo "Build completed without the expected Image: ${image_path}" >&2
    exit 1
fi

echo "Kernel release:"
make "${make_args[@]}" -s kernelrelease
echo "Candidate artifacts:"
sha256sum \
    "${output_dir}/.config" \
    "${image_path}" \
    "${output_dir}/Module.symvers" \
    "${output_dir}/System.map"
