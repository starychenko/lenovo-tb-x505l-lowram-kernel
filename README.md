# Lenovo TB-X505L low-RAM kernel

Validated Linux 4.9.205 kernel work for the 2 GB RAM Lenovo Tab M10 HD
TB-X505L. The current r6 build was qualified on crDroid 9.10 Android 13 PHH
GSI with the stock Android 10 vendor partition.

[Українська версія](README.uk.md) · [Installation](docs/INSTALL.md) · [Build](docs/BUILD.md) · [r6 engineering](docs/R6_ENGINEERING.md) · [r5 validation](docs/VALIDATION.md) · [Archive inventory](docs/ARCHIVE_INVENTORY.md)

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

| Area | Stock configuration | r6 |
|---|---|---|
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

The final `r6` image first completed a temporary `fastboot boot` and was then
flashed permanently. The following were verified:

- all 25 required Lenovo modules loaded;
- audio card, speakers, Wi-Fi, front/rear cameras, touch and gestures;
- microphone input works, although the tested tablet's microphone is weak and may have a mechanical defect;
- PSI, KSM, 1 GiB LZ4 zRAM and userspace `lmkd` integration;
- final native CPU, RAM, wake-up-latency and direct-I/O smoke test;
- final Android launch and 621-frame Settings-scroll smoke test;
- Bluetooth OFF -> ON -> OFF, active accelerometer and two camera devices;
- written boot-partition SHA-256 matched the released image exactly.

The r6 work also includes three controlled kernel candidates, custom subsystem
benchmarks, repeated UI runs and PCMark Work/Storage comparisons. See
[docs/R6_ENGINEERING.md](docs/R6_ENGINEERING.md) for the results and evidence
limits. The original r5 memory-pressure qualification remains in
[docs/VALIDATION.md](docs/VALIDATION.md).

## Quick start

1. Download `tb-x505l-lowram-r6-boot.img` and `SHA256SUMS.txt` from the latest release.
2. Verify the SHA-256 checksum.
3. Back up your own boot partition.
4. Test without flashing:

```text
adb reboot bootloader
fastboot boot tb-x505l-lowram-r6-boot.img
```

5. Verify all hardware. Only then flash permanently:

```text
adb reboot bootloader
fastboot flash boot tb-x505l-lowram-r6-boot.img
fastboot reboot
```

The tested tablet has a faulty Volume Up button, so all recovery-safe paths use `adb reboot bootloader` when Android is still available. Full instructions and rollback steps are in [docs/INSTALL.md](docs/INSTALL.md).

## Repository contents

- `configs/` - exact baseline and final kernel configurations.
- `benchmarks/` - the native AArch64 CPU/RAM/latency/I/O benchmark source.
- `analysis/` - generic module ABI and upstream-snapshot investigation tools.
- `patches/` - validated source patch shared by r5 and r6.
- `device/` - the PHH low-RAM hook and reversible Android 13 runtime profile.
- `firmware/` - exact factory-package identity and checksum metadata.
- `historical/` - rejected engineering approaches retained with warnings.
- `reproducibility/` - byte-for-byte build notes and X.509 generation recipe.
- `scripts/` - reproducible build, repack, temporary-boot and checksum tools.
- `docs/` - build provenance, development history, technical decisions and validation.
- GitHub Releases - final and engineering artifacts, both source states, exact
  toolchains, reproducibility material and checksums.

Non-release engineering images are preserved in a separate archive and clearly
marked as unsupported rather than presented as flashable releases.

## Source provenance

The exact staged Lenovo source tree used as the base is Git tree `6764b8e36f9506f89cee6f1e7711cd54ae54d32b`, materialized on top of CAF commit `4e699d80a1f43d3dd380d1c7a50cc8fa0ee30440` (`LA.UM.8.6.2.r1-06100-89xx.0`). Using the CAF commit alone is not sufficient; the release contains the complete corresponding source archive.

Related upstream work:

- [Lenovo-TB-X505X kernel repository](https://github.com/Lenovo-TB-X505X/android_kernel_lenovo_TB-X505X)
- [PHH Treble experiments](https://github.com/phhusson/treble_experimentations)
- [Magisk / MagiskBoot](https://github.com/topjohnwu/Magisk)

## License

Kernel source, kernel changes and project-authored code are distributed under
GPL-2.0-only. Complete PHH base files are referenced, not redistributed; see
[LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
