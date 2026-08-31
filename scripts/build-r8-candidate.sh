#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <r8-kernel-source> <clang-r365631c-dir> <aarch64-gcc-4.9-dir> <config> <output-dir> [reproducibility-key.pem] [arm32-gcc-4.9-dir]" >&2
}

if [[ $# -lt 5 || $# -gt 7 ]]; then
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
arm32_gcc_dir="${7:-}"
build_timestamp="${TB_X505L_BUILD_TIMESTAMP:-Mon Aug 31 22:30:00 UTC 2026}"
build_version="${TB_X505L_BUILD_VERSION:-17}"
build_jobs="${TB_X505L_BUILD_JOBS:-8}"
build_user="${TB_X505L_BUILD_USER:-codex-r8}"
build_host="${TB_X505L_BUILD_HOST:-tb-x505l}"

if [[ ! "${build_jobs}" =~ ^[1-9][0-9]*$ ]]; then
    echo "TB_X505L_BUILD_JOBS must be a positive integer: ${build_jobs}" >&2
    exit 2
fi

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

if [[ -n "${arm32_gcc_dir}" ]]; then
    arm32_gcc_dir="$(realpath "${arm32_gcc_dir}")"
    if [[ ! -x "${arm32_gcc_dir}/bin/arm-linux-androideabi-gcc" ]]; then
        echo "ARM32 GCC 4.9 toolchain not found in ${arm32_gcc_dir}/bin" >&2
        exit 1
    fi
fi

if [[ ! -f "${config_source}" ]]; then
    echo "Release config not found: ${config_source}" >&2
    exit 1
fi

if grep -Fqx 'CONFIG_COMPAT_VDSO=y' "${config_source}" && [[ -z "${arm32_gcc_dir}" ]]; then
    echo "CONFIG_COMPAT_VDSO=y requires the ARM32 GCC 4.9 toolchain argument." >&2
    exit 1
fi

kernel_version="$(make -s -C "${kernel_source}" kernelversion)"
if [[ "${kernel_version}" != "4.9.337" ]]; then
    echo "Refusing a non-r8 source version: ${kernel_version}" >&2
    exit 1
fi

if ! grep -Fq 'tb_x505l_vendor_module' "${kernel_source}/kernel/module.c"; then
    echo "TB-X505L vendor-module compatibility policy is missing." >&2
    exit 1
fi

if ! grep -Fq 'atomic_cmpxchg(&qos_add_request_done, 1, 0)' \
    "${kernel_source}/drivers/media/platform/msm/camera_v2/msm.c"; then
    echo "The qualified camera PM QoS lifecycle fix is missing." >&2
    exit 1
fi

if ! grep -Eq '^CONFIG_LOCALVERSION="-tbx505l-r8-[a-z0-9.-]+"$' \
    "${config_source}"; then
    echo "Refusing a config without a valid r8 candidate local version." >&2
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
if git -C "${kernel_source}" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "${kernel_source}" log -1 --oneline
else
    echo "Source archive without Git metadata"
fi
echo "Compiler:"
"${clang_dir}/bin/clang" --version | head -n 1
echo "Input config:"
sha256sum "${config_source}"
echo "Build identity: user=${build_user}, host=${build_host}, version=${build_version}, timestamp=${build_timestamp}"
echo "Build resources: jobs=${build_jobs}"

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

if [[ -n "${arm32_gcc_dir}" ]]; then
    make_args+=(
        CROSS_COMPILE_ARM32="${arm32_gcc_dir}/bin/arm-linux-androideabi-"
    )
fi

build_env=(
    KBUILD_BUILD_USER="${build_user}"
    KBUILD_BUILD_HOST="${build_host}"
    KBUILD_BUILD_VERSION="${build_version}"
    KBUILD_BUILD_TIMESTAMP="${build_timestamp}"
)

env "${build_env[@]}" make "${make_args[@]}" olddefconfig
env "${build_env[@]}" make "${make_args[@]}" usr/
env "${build_env[@]}" make "${make_args[@]}" -j"${build_jobs}" Image

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
