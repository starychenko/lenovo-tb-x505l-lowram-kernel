# r5 validation record (historical)

This file preserves the original r5 qualification. Current r8-c8 validation,
hashes and evidence limits are in [R8_ENGINEERING.md](R8_ENGINEERING.md) and
the [r8-c8 evidence index](../benchmarks/results/r8-c8/README.md).

## Artifact identity

```text
boot.img       3dabe282b5f82efa5d4e7496835aca8731d6d1ed3975e281adedeba2fdb3b61f
Image          4d543f6c817aa11528489338a01e7e7c9158223ead52a2db165d9964bfba3779
config         f9ad24525e98e579474ab7a3b0b5037646fd90aa113a27eed9275e64cd1c4cf5
System.map     3ba5ecda85ede33aa4ea8c8e73ce070afcdf3224fec0b3701eb67913335b4420
Module.symvers 7c74085e951663ba6185e7576a59f62f3faa0157d86d0001aac494d428e2614e
stock DTB      e95ed19a66da21c63f5943e50fba34e023cf227882ebb9360747a8dc716e59e7
```

A clean source extraction plus the published patch, config, archived
toolchains, reproducibility key and pinned build layout produced the same raw
`Image` SHA-256 byte for byte. The clean build also reproduced the exact
`System.map`, `Module.symvers`, generated `compile.h` and embedded certificate.

MagiskBoot unpacked the release image and reproduced the `Image` and stock-DTB hashes above. Header fields, empty ramdisk and total 64 MiB size were also checked before the first boot.

## Boot qualification

- Temporary `fastboot boot`: three successful complete Android starts.
- Final clean temporary boot: successful after removing the modified `phh-on-data.sh`, late loader and rebuilt-module directory.
- Permanent flash: bootloader reported successful write, Android completed boot, and a readback of `/dev/block/by-name/boot` matched the release boot hash exactly.

Runtime identity:

```text
Linux localhost 4.9.205-perf+ #5 SMP PREEMPT Sun Aug 30 21:18:08 UTC 2026 aarch64
Android Clang 9.0.8, build r365631c
```

## Runtime checks

| Check | Result |
|---|---|
| Android `sys.boot_completed` | `1` |
| Required modules | 25/25 loaded |
| Audio card | `sdm439-snd-card-mtp` |
| Audio HAL / audioserver | running |
| Wi-Fi HAL / `wlan0` | running / up |
| Camera devices | 2 |
| PSI interface | present and active |
| `lmkd` PSI monitors | two FDs open to `/proc/pressure/memory` |
| zRAM size | 1,073,741,824 bytes |
| zRAM compressor | `[lz4]` |
| KSM | `run=1` |
| swappiness | `100` |
| page cluster | `0` |
| late fallback loader | absent |

## Memory-pressure tests

The test program allocates and touches anonymous memory, holds it for 30 seconds and exits with a deterministic checksum.

### Final r5: 700 MiB

- resident allocation reached approximately 700 MiB;
- `MemAvailable` fell to roughly 394-401 MiB during the hold;
- PSI `some` rose and `full` pressure was observable;
- audio and Wi-Fi HALs stayed running throughout samples;
- no OOM kill, kernel BUG, Oops, call trace or hung task;
- `MemAvailable` recovered to approximately 1.1 GiB after exit.

### Engineering r3: 900 MiB

The earlier build used the same low-RAM config and working stock-module strategy. A 900 MiB test completed, reached approximately 922 MiB RSS, left about 233 MiB available at peak pressure and recovered without a kernel fault. This result supported the design, but only r5 is released.

## Physical checks

The owner tested the final r5 temporary image before permanent flashing:

- Wi-Fi: works;
- speakers/audio: works;
- front and rear cameras: work;
- touch: works;
- gesture navigation: works;
- microphone: records, but quality is poor and likely reflects a mechanical defect.

The same boot image was then permanently flashed and verified by hash. No source or packaging change occurred between physical testing and flashing.

## Negative checks

The kernel log was scanned after clean boot and after stress for:

```text
BUG:
Oops:
Call trace:
hung task
Out of memory
oom-kill
Kernel panic
Unable to handle kernel
Unknown symbol
disagrees about version
```

No matching kernel fault was present. Normal vendor Wi-Fi diagnostic noise and expected module-taint messages are not classified as kernel crashes.

## Evidence boundary

This validation covers one TB-X505L 2/32 GB unit and one vendor/GSI combination. It does not prove compatibility with another regional build, a different TB-X505 variant, encrypted stock ROM, cellular behavior under every carrier, long-term battery aging or security properties.
