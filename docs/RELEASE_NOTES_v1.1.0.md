# v1.1.0 - TB-X505L low-RAM kernel r6

r6 keeps the r5 low-memory and Lenovo module-compatibility work, changes the
default eMMC I/O scheduler from CFQ to deadline, and adds an optional measured
Android 13 responsiveness profile. It was qualified on one TB-X505L 2/32 GB
with crDroid 9.10 Android 13 PHH GSI and Lenovo vendor
`X505L_S001149_221018_ROW`.

## Final artifact identity

```text
tb-x505l-lowram-r6-boot.img
9e9bba24ab8af0ca19fc655ded6339a1fd1cfe3f944364aa61a0be2d917b8a72

tb-x505l-lowram-r6-Image
974d7ce683b25252743901f618cbb1024a66080ee684ba507dcbac657329f886

tb-x505l-lowram-r6-config
055df656f6cbfaf33afa7c61153e537b96d3772181e078ff52c7501b21969353

tb-x505l-lowram-r6-System.map
0d35d8c0ca2f435799f9fdd515df7293b79b9fd8bd788637ec44be7839b3ecda

tb-x505l-lowram-r6-Module.symvers
7c74085e951663ba6185e7576a59f62f3faa0157d86d0001aac494d428e2614e
```

Runtime identity:

```text
Linux localhost 4.9.205-tbx505l-r6+ #7 SMP PREEMPT
Mon Aug 31 11:45:00 UTC 2026 aarch64
```

The final boot image preserves the verified Lenovo DTB hash
`e95ed19a66da21c63f5943e50fba34e023cf227882ebb9360747a8dc716e59e7`,
header v1, command line, Android 10 OS metadata and zero-length Android
ramdisk.

## What was measured

- 300 Hz was rejected after worse cross-core latency tails, Settings p95/p99
  and small app-launch regressions.
- 100 Hz + deadline kept r5-like CPU/UI behavior while improving the direction
  of direct random-I/O latency and IOPS.
- The optional balanced Android profile improved a warm PCMark Work run by
  1.8% and the mean of two PCMark Storage runs by 6.7% on the same r6 kernel.
- Repeated Settings scrolls improved p50 from 12 ms to 10 ms and kept p99 at
  18 ms.
- The profile used about 5.6% more CPU cycles in the controlled UI proxy. No
  unplugged battery-life claim is made.

Full tables and limits are in `docs/R6_ENGINEERING.md`.

## Installation

Always test without writing the boot partition first:

```text
adb reboot bootloader
fastboot boot tb-x505l-lowram-r6-boot.img
```

Check touch, gestures, Wi-Fi, speakers, both cameras, microphone, Bluetooth,
rotation, charging and sleep/wake. Only then flash:

```text
adb reboot bootloader
fastboot flash boot tb-x505l-lowram-r6-boot.img
fastboot reboot
```

The Android 13 profile is installed separately from
`device/crdroid13-balanced-profile/`; it is not hidden inside `boot.img` and
can be removed without reflashing the kernel.

## Validation boundary

Do not flash this image on TB-X505F, TB-X505X, another vendor build or another
storage/RAM configuration based on the product name alone. The kernel remains
Linux 4.9 with an old Lenovo vendor security level, and its deliberate module
signature/CRC compatibility policy is unsuitable for a security-sensitive
device. Keep a verified boot backup from the exact tablet.
