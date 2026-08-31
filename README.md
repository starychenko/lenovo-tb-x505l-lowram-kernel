# Lenovo TB-X505L low-RAM kernel

Validated Linux 4.9.337 kernel work for the 2 GB RAM Lenovo Tab M10 HD
TB-X505L. The final v1.4.0 image is r8-c9: the qualified r8 scheduler/KGSL,
ARM64, optional BFQ and A53 ThinLTO work plus a measured 364.5 MHz GPU level
and a 1305.6 MHz CPU floor. r7 remains the conservative rollback image.

[Українська версія](README.uk.md) · [Installation](docs/INSTALL.md) · [Build](docs/BUILD.md) · [GPU clock investigation](docs/GPU_OVERCLOCK.md) · [r8 engineering](docs/R8_ENGINEERING.md) · [Kernel roadmap](docs/KERNEL_ROADMAP.uk.md) · [Performance dynamics](docs/PERFORMANCE_DYNAMICS.md) · [r7 engineering](docs/R7_ENGINEERING.md) · [Camera HAL logging](docs/CAMERA_HAL_LOGGING.md) · [Archive inventory](docs/ARCHIVE_INVENTORY.md)

## Read this first

This is a device-specific kernel, not a generic image. It was physically tested only on:

- Lenovo TB-X505L, 2 GB RAM / 32 GB storage
- Qualcomm Snapdragon 429 / SDM439 family
- stock vendor build `TB-X505L_S001149_221018_ROW`
- crDroid 9.10 PHH GSI, Android 13
- unlocked bootloader

Do not flash it on TB-X505F, TB-X505X, a different memory configuration, or another vendor build without first proving compatibility with `fastboot boot`. Back up your own boot partition before making a permanent change.

The stock Lenovo boot image and proprietary vendor modules are deliberately not distributed by this project.

## What changed

| Area | Stock configuration | r7 |
|---|---|---|
| Kernel line | Lenovo/CAF Linux 4.9.205 | staged CAF integration followed by Linux 4.9.337 |
| Memory pressure | PSI disabled | `CONFIG_PSI=y`; Android `lmkd` uses `/proc/pressure/memory` |
| Memory cgroups | disabled | `CONFIG_MEMCG=y`, swap accounting enabled |
| Low-memory killing | legacy in-kernel LMK | legacy LMK disabled; userspace `lmkd` handles pressure |
| zRAM | LZO default | LZ4 support enabled and selected by default |
| Same-page merging | disabled | KSM enabled and active |
| Swap read cluster | kernel default | device-scoped `vm.page-cluster=0` PHH hook |
| Vendor modules | fail against the rebuilt ABI/key | exact 25-name Lenovo audio/WLAN CRC compatibility allowlist |
| eMMC scheduler | CFQ | deadline, after controlled CFQ/deadline comparison |
| Android task policy | ROM defaults | optional, reversible measured EAS/schedutil profile |

The release keeps the stock device tree, boot header, command line and empty ramdisk. Only the kernel payload changes.

The final r8-c9 release extends r7 without changing those boot-format
constraints. BFQ is available but `deadline` remains the default. c9 raises
the lowest CPU level from 960 to 1305.6 MHz while retaining the 2016 MHz
maximum, and adds a real measured 364.5 MHz GPU level above the retained
320 MHz level. It passed temporary and permanent boot, exact boot-partition
readback, hardware, ABI, GPU, mixed CPU/GPU stress and production-profile
validation on the tested tablet.

## Why this exists

The tablet has only 2 GB of RAM. Both the original Android 11 qualification
GSI and the current Android 13 GSI contain modern userspace `lmkd`, but the
stock kernel had PSI and memory cgroups disabled while retaining the old
in-kernel low-memory killer. Enabling the PSI-backed memory-pressure path made
the software stack internally consistent:

- PSI reports real memory stalls.
- `lmkd` registers two monitors on `/proc/pressure/memory`.
- zRAM remains 1 GiB and uses LZ4.
- KSM can merge eligible anonymous pages.
- the legacy kernel LMK no longer competes with userspace `lmkd`.

Android documents PSI-backed `lmkd` and the required kernel options in the [AOSP lmkd documentation](https://source.android.com/docs/core/perf/lmkd). Kernel interfaces are documented in [PSI](https://docs.kernel.org/accounting/psi.html), [zRAM](https://docs.kernel.org/admin-guide/blockdev/zram.html) and [KSM](https://docs.kernel.org/admin-guide/mm/ksm.html).

## Vendor-module compatibility and security

Lenovo's shipping audio and WLAN modules contain device-specific behavior that was not reproducible from the available public source alone. Rebuilt audio modules also loaded too late from the GSI data hook and missed early hardware probe events. The working design therefore keeps the exact modules already present on the stock vendor partition and changes the kernel compatibility policy:

- symbol-version CRC drift is accepted only for 25 explicit internal module names;
- every other module still uses normal `CONFIG_MODVERSIONS` enforcement;
- the rebuilt kernel does not possess Lenovo's private signing key, so trusted-key enforcement is permissive;
- malformed signatures remain rejected, but a root user can load an unsigned module;
- the expected kernel taint is `12290`, and the stock modules appear as `(OFE)`.

This is a real security trade-off. Read [SECURITY.md](SECURITY.md) and the kernel's [module-signing documentation](https://docs.kernel.org/admin-guide/module-signing.html) before using the image on a security-sensitive device.

## Tested result

The final r7 and r8-c9 images each completed temporary boot before permanent
flashing. The following were verified on c9:

- all 25 required Lenovo modules loaded;
- audio card, speakers, Wi-Fi, front/rear cameras, touch and gestures;
- microphone input works, although the tested tablet's microphone is weak and may have a mechanical defect;
- PSI, KSM, 1 GiB LZ4 zRAM and userspace `lmkd` integration;
- controlled native CPU, RAM, wake-up-latency and direct-I/O comparisons;
- repeated Android launch and Settings-scroll comparisons;
- Bluetooth OFF -> ON -> OFF, active accelerometer and two camera devices;
- repeated camera lifecycles after the PM QoS fix;
- c9 boot-partition readback exactly matched its published SHA-256;
- the first permanent-boot dmesg fault scan was clean;
- the Goodix touchscreen uses the changed Qualcomm I2C v2 path and
  `compact_unevictable_allowed=0` is live;
- the corrected balanced profile applied at the PHH hook and again after boot;
- BFQ v8r10 is selectable while `deadline` remains selected after boot;
- ThinLTO/A53 config, the SDM429 KGSL 1000 us active-latency vote and all 25
  vendor-module symbol requirements passed the final validator;
- two 256 MiB workers completed 16 memory rounds without an OOM or kernel fault.
- the GPU branch measured 364.498-364.503 MHz under load, five short runs
  averaged 14.463 FPS versus 12.702 FPS at 320 MHz, and concurrent four-thread
  CPU plus GPU stress peaked at 54 C without a GPU fault or clock reset.

The r7 work preserves the complete 4.9.206 -> 4.9.227 -> 4.9.337 integration
history, module ABI audit, custom subsystem benchmarks, UI controls, a 700 MiB
memory-pressure run and camera diagnosis. See
[docs/R7_ENGINEERING.md](docs/R7_ENGINEERING.md) for the results and evidence
limits. r6 and the original r5 qualification remain documented separately.

## Quick start

1. Download `tb-x505l-r8-c9-oc3645-cpu1305-boot.img` from the latest stable
   release together with `SHA256SUMS.txt`. Keep your own boot backup; the older
   `tb-x505l-lowram-r7-boot.img` remains available from v1.2.0 as a conservative
   project fallback for the exact tested vendor.
2. Verify the SHA-256 checksum.
3. Back up your own boot partition.
4. Test without flashing:

```text
adb reboot bootloader
fastboot boot tb-x505l-r8-c9-oc3645-cpu1305-boot.img
```

5. Verify all hardware. Only then flash permanently:

```text
adb reboot bootloader
fastboot flash boot tb-x505l-r8-c9-oc3645-cpu1305-boot.img
fastboot reboot
```

Never flash an image that did not first complete the temporary hardware test
on the same device and vendor build.

The tested tablet has a faulty Volume Up button, so all recovery-safe paths use `adb reboot bootloader` when Android is still available. Full instructions and rollback steps are in [docs/INSTALL.md](docs/INSTALL.md).

## Repository contents

- `configs/` - exact baseline, candidate and final kernel configurations.
- `benchmarks/` - native AArch64 CPU/RAM/latency/I/O and EGL/GLES GPU benchmark source.
- `analysis/` - generic module ABI and upstream-snapshot investigation tools.
- `patches/` - validated older deltas, the ordered r8 c4-c8 series and the
  independently reproducible c9 CPU/GPU patch.
- `device/` - the PHH low-RAM hook and reversible Android 13 runtime profile.
- `firmware/` - exact factory-package identity and checksum metadata.
- `historical/` - rejected engineering approaches retained with warnings.
- `reproducibility/` - byte-for-byte build notes and X.509 generation recipe.
- `scripts/` - reproducible build, repack, temporary-boot and checksum tools.
- `docs/` - build provenance, development history, technical decisions and validation.
- GitHub Releases - final and engineering artifacts, both source states, exact
  toolchains, reproducibility material and checksums.

Privacy-reviewed engineering evidence is preserved in a separate release
archive. Intermediate images remain unsupported and are not presented as
flashable releases.

## Source provenance

The original device base is the staged Lenovo tree
`6764b8e36f9506f89cee6f1e7711cd54ae54d32b` on CAF commit
`4e699d80a1f43d3dd380d1c7a50cc8fa0ee30440`. r7 integrates that device line
through CAF 4.9.206/4.9.227 into KudProject's Linux 4.9.337 commit
`cad7430de0364a908d73cea93d06f9ca44ad439e`; the qualified final source commit
is `ca9f99dcda9bc0cf55271157d3a5718ed8cf6e3b`. r8-c3 ends at
`45a98eac292f8b1fbf6f8e5b1130805691327e68`; r8-c8 ends at
`40a80480379791338dfacb3d8a2b3d755c655bad`; final r8-c9 ends at
`0ea8dc3e34140ac48640f23dacf8b9a04fd2b26e`. The published patch series
reconstructs it from the archived r7/c3/c8 states without depending on a
moving donor branch.

Related upstream work:

- [Lenovo-TB-X505X kernel repository](https://github.com/Lenovo-TB-X505X/android_kernel_lenovo_TB-X505X)
- [KudProject kernel_msm-4.9](https://github.com/KudProject/kernel_msm-4.9)
- [PHH Treble experiments](https://github.com/phhusson/treble_experimentations)
- [Magisk / MagiskBoot](https://github.com/topjohnwu/Magisk)

## License

Kernel source, kernel changes and project-authored code are distributed under
GPL-2.0-only. Complete PHH base files are referenced, not redistributed; see
[LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
