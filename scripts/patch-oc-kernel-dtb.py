#!/usr/bin/env python3
"""Patch the selected DTB inside the TB-X505L concatenated kernel_dtb stream.

The qualified release value is 364.5 MHz. Other accepted values only preserve
rejected engineering experiments and require an explicit opt-in.
"""

from __future__ import annotations

import argparse
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


FDT_MAGIC = b"\xd0\x0d\xfe\xed"
CPUFREQ_NODE = "/soc/qcom,msm-cpufreq"
GPU_BIN_NODE = (
    "/soc/qcom,kgsl-3d0/qcom,gpu-pwrlevel-bins/qcom,gpu-pwrlevels-3"
)


def run(*args: str) -> str:
    result = subprocess.run(args, check=True, text=True, capture_output=True)
    return result.stdout.strip()


def split_dtbs(data: bytes) -> list[bytes]:
    blobs: list[bytes] = []
    offset = 0
    while offset < len(data):
        if data[offset : offset + 4] != FDT_MAGIC:
            raise ValueError(f"invalid FDT magic at byte {offset}")
        if offset + 40 > len(data):
            raise ValueError(f"truncated FDT header at byte {offset}")
        total_size = struct.unpack_from(">I", data, offset + 4)[0]
        if total_size < 40 or offset + total_size > len(data):
            raise ValueError(f"invalid FDT size {total_size} at byte {offset}")
        blobs.append(data[offset : offset + total_size])
        offset += total_size
    return blobs


def get_string(fdtget: str, dtb: Path, node: str, property_name: str) -> str:
    return run(fdtget, "-t", "s", str(dtb), node, property_name)


def get_ints(fdtget: str, dtb: Path, node: str, property_name: str) -> list[int]:
    output = run(fdtget, "-t", "i", str(dtb), node, property_name)
    return [int(value, 0) for value in output.split()]


def put_ints(fdtput: str, dtb: Path, node: str, property_name: str, *values: int) -> None:
    run(fdtput, "-t", "i", str(dtb), node, property_name, *map(str, values))


def patch_selected_dtb(
    dtb: Path, fdtget: str, fdtput: str, gpu_frequency: int
) -> None:
    gpu_bus_votes = {
        364500000: (5, 4, 7),
        400000000: (5, 4, 7),
        432000000: (7, 6, 8),
        540000000: (8, 7, 9),
    }
    if gpu_frequency not in gpu_bus_votes:
        raise ValueError(
            f"unsupported experimental GPU frequency: {gpu_frequency}; "
            f"expected one of {sorted(gpu_bus_votes)}"
        )
    bus_freq, bus_min, bus_max = gpu_bus_votes[gpu_frequency]

    model = get_string(fdtget, dtb, "/", "model")
    compatible = get_string(fdtget, dtb, "/", "compatible")
    if model != "Qualcomm Technologies, Inc. SDM429 MTP" or "qcom,sdm429" not in compatible:
        raise ValueError(f"refusing unexpected DTB: model={model!r} compatible={compatible!r}")

    cpu_frequencies = get_ints(fdtget, dtb, CPUFREQ_NODE, "qcom,cpufreq-table")
    if cpu_frequencies != [960000, 1305600, 1497600, 1708800, 1804800, 1958400, 2016000]:
        raise ValueError(f"unexpected CPU table: {cpu_frequencies}")

    speed_bin = get_ints(fdtget, dtb, GPU_BIN_NODE, "qcom,speed-bin")
    gpu0 = f"{GPU_BIN_NODE}/qcom,gpu-pwrlevel@0"
    gpu1 = f"{GPU_BIN_NODE}/qcom,gpu-pwrlevel@1"
    gpu2 = f"{GPU_BIN_NODE}/qcom,gpu-pwrlevel@2"
    if speed_bin != [10] or get_ints(fdtget, dtb, gpu0, "qcom,gpu-freq") != [320000000]:
        raise ValueError("the selected DTB is not the expected speed-bin 10 / 320 MHz layout")
    if get_ints(fdtget, dtb, gpu1, "qcom,gpu-freq") != [19200000]:
        raise ValueError("the selected DTB has an unexpected XO GPU power level")

    put_ints(fdtput, dtb, CPUFREQ_NODE, "qcom,cpufreq-table",
             1305600, 1497600, 1708800, 1804800, 1958400, 2016000)

    run(fdtput, "-c", str(dtb), gpu2)
    put_ints(fdtput, dtb, gpu2, "reg", 2)
    put_ints(fdtput, dtb, gpu2, "qcom,gpu-freq", 19200000)
    put_ints(fdtput, dtb, gpu2, "qcom,bus-freq", 0)
    put_ints(fdtput, dtb, gpu2, "qcom,bus-min", 0)
    put_ints(fdtput, dtb, gpu2, "qcom,bus-max", 0)

    put_ints(fdtput, dtb, gpu1, "reg", 1)
    put_ints(fdtput, dtb, gpu1, "qcom,gpu-freq", 320000000)
    put_ints(fdtput, dtb, gpu1, "qcom,bus-freq", 4)
    put_ints(fdtput, dtb, gpu1, "qcom,bus-min", 4)
    put_ints(fdtput, dtb, gpu1, "qcom,bus-max", 8)

    put_ints(fdtput, dtb, gpu0, "reg", 0)
    put_ints(fdtput, dtb, gpu0, "qcom,gpu-freq", gpu_frequency)
    put_ints(fdtput, dtb, gpu0, "qcom,bus-freq", bus_freq)
    put_ints(fdtput, dtb, gpu0, "qcom,bus-min", bus_min)
    put_ints(fdtput, dtb, gpu0, "qcom,bus-max", bus_max)

    if get_ints(fdtget, dtb, CPUFREQ_NODE, "qcom,cpufreq-table")[0] != 1305600:
        raise RuntimeError("CPU floor verification failed")
    if get_ints(fdtget, dtb, gpu0, "qcom,gpu-freq") != [gpu_frequency]:
        raise RuntimeError(f"{gpu_frequency} Hz GPU level verification failed")
    if get_ints(fdtget, dtb, gpu1, "qcom,gpu-freq") != [320000000]:
        raise RuntimeError("320 MHz GPU level verification failed")
    if get_ints(fdtget, dtb, gpu2, "qcom,gpu-freq") != [19200000]:
        raise RuntimeError("XO GPU level verification failed")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--index", type=int, default=1)
    parser.add_argument("--gpu-frequency", type=int, default=364500000)
    parser.add_argument(
        "--allow-experimental",
        action="store_true",
        help="allow rejected 400/432/540 MHz engineering values",
    )
    parser.add_argument("--fdtget", default="fdtget")
    parser.add_argument("--fdtput", default="fdtput")
    args = parser.parse_args()

    if args.gpu_frequency != 364500000 and not args.allow_experimental:
        raise SystemExit(
            "only the qualified 364500000 Hz value is enabled by default; "
            "pass --allow-experimental solely to reproduce a rejected test"
        )

    for tool in (args.fdtget, args.fdtput):
        if not shutil.which(tool):
            raise SystemExit(f"required tool not found: {tool}")

    source = args.input.read_bytes()
    blobs = split_dtbs(source)
    if args.index < 0 or args.index >= len(blobs):
        raise SystemExit(f"DTB index {args.index} is outside 0..{len(blobs) - 1}")

    with tempfile.TemporaryDirectory(prefix="tbx505l-dtb-") as temporary:
        selected = Path(temporary) / "selected.dtb"
        selected.write_bytes(blobs[args.index])
        patch_selected_dtb(
            selected, args.fdtget, args.fdtput, args.gpu_frequency
        )
        blobs[args.index] = selected.read_bytes()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(b"".join(blobs))
    verified = split_dtbs(args.output.read_bytes())
    if len(verified) != len(blobs):
        raise RuntimeError("reassembled DTB count changed")

    print(f"dtb_count={len(blobs)}")
    print(f"patched_index={args.index}")
    print(f"input_bytes={len(source)}")
    print(f"output_bytes={args.output.stat().st_size}")


if __name__ == "__main__":
    main()
