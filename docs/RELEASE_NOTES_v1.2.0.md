# v1.2.0 - TB-X505L Linux 4.9.337 kernel r7

r7 moves the device kernel from Linux 4.9.205 to 4.9.337 while preserving the
qualified TB-X505L low-memory behavior and the exact Lenovo audio/WLAN module
set. It was tested and permanently installed on one TB-X505L 2/32 GB running
crDroid 9.10 Android 13 PHH GSI with Lenovo Android 10 vendor
`X505L_S001149_221018_ROW`.

## Artifact identity

```text
tb-x505l-lowram-r7-boot.img
4c30c952703b5d509953a06c4a66cfee60f08395f06555e2e5027623b9846cc3

tb-x505l-lowram-r7-Image
2ddcf2b84d3b4e5588d3ab43c7ac4835c0249c57e2a6e01d0ec665d074ba6de1

tb-x505l-lowram-r7-config
ddb6b6277eedc4f0c45c55a2196d1fb5ffb1fe15409e86a4568124d099845fac

tb-x505l-lowram-r7-System.map
2cc922803e61f6eeb526736ac8a1cd206ea0811eb9dd19aef8cec1892ccddc5f

tb-x505l-lowram-r7-Module.symvers
5844ecfc61a6dee4ec2ec2b91659a0625528b0c883fd3f6c0dfdfb5ca8226a0d
```

Runtime identity:

```text
Linux localhost 4.9.337-tbx505l-r7-4.9.337-compat-vendor+ #14 SMP PREEMPT
Mon Aug 31 10:45:00 UTC 2026 aarch64
```

The boot image is exactly 67,108,864 bytes. Its DTB SHA-256 is
`e95ed19a66da21c63f5943e50fba34e023cf227882ebb9360747a8dc716e59e7`,
identical to the qualified Lenovo input boot image.

## What changed

- Integrated the device line through CAF 4.9.206 and 4.9.227 into a Linux
  4.9.337 KudProject baseline.
- Preserved PSI, memory cgroups, userspace `lmkd`, KSM, LZ4 zRAM, deadline I/O
  and the narrow 25-module Lenovo compatibility policy from r6.
- Added a legacy KGSL scratch-layout adaptation needed by the shipping Adreno
  firmware.
- Restored `__fsl_a008585_read_cntvct_el0`, the one kernel symbol missing from
  the first 4.9.337 audit of all 25 Lenovo modules.
- Fixed the Qualcomm camera PM QoS request lifecycle that produced warnings
  after repeated camera close/reopen cycles.
- Added a reversible Camera HAL verbosity helper. It changes supported
  properties only and does not modify proprietary camera files.
- Extended the optional crDroid 13 balanced profile to r7, including migration
  of existing r6-only boot-hook markers and exact readback verification.
- Added reusable module-CRC, memory-pressure and camera logging/diagnostic
  scripts plus complete source, config and validation documentation.

## Validation

- Final c4 image completed temporary boot and permanent flash.
- The written boot partition SHA-256 matched the release image.
- All 25 Lenovo modules loaded with zero missing kernel symbols.
- Wi-Fi and real Internet traffic, Bluetooth, audio card, touch, both cameras,
  microphone and accelerometer were checked.
- `deadline`, PSI, KSM, LZ4 zRAM and userspace `lmkd` remained active.
- The first permanent-boot fault scan contained no panic, BUG, Oops, WARNING or
  call trace.
- A 700 MiB memory-pressure workload completed both workers. Two order-0
  `GFP_ATOMIC` allocation failures occurred only near 18 MiB available RAM.
- Controlled CPU results were effectively unchanged from 4.9.227; memory-copy
  and read medians improved, while several direct-I/O and Settings-jank metrics
  regressed. No universal performance claim is made.

Full candidate history, tables and limitations are in
`docs/R7_ENGINEERING.md`.

## Reproducible inputs

The release includes:

- complete corresponding r7 source at commit
  `ca9f99dcda9bc0cf55271157d3a5718ed8cf6e3b`;
- exact config, `Image`, `System.map`, `Module.symvers` and `compile.h`;
- a project archive containing the public scripts, configs, patches and docs;
- a privacy-reviewed validation-evidence archive;
- the public project reproducibility-key archive;
- one SHA-256 manifest covering every attached asset.

The exact Clang r365631c and AArch64 GCC 4.9 archives remain attached to
v1.0.0 instead of being duplicated. Lenovo factory images, proprietary vendor
blobs, device backups, identifiers, photos and APKs are not included.

## Installation

Back up the matching boot partition, then test without writing it:

```text
adb reboot bootloader
fastboot boot tb-x505l-lowram-r7-boot.img
```

Verify touch, gestures, Wi-Fi, speakers, both cameras, microphone, Bluetooth,
rotation, charging and sleep/wake. Only then flash:

```text
adb reboot bootloader
fastboot flash boot tb-x505l-lowram-r7-boot.img
fastboot reboot
```

After boot, a rooted readback must produce the release hash:

```text
adb shell "dd if=/dev/block/by-name/boot bs=1048576 2>/dev/null | sha256sum"
```

## Security and compatibility boundary

Do not flash this image on TB-X505F, TB-X505X, another RAM/storage variant or a
different vendor build based on the product name alone. Linux 4.9 is
end-of-life, the Lenovo Android 10 vendor remains old, and the deliberate
module-signature/CRC compatibility policy is inappropriate for a
security-sensitive device. Keep a verified boot backup from the exact tablet.
