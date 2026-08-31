# v1.0.0 - TB-X505L low-RAM kernel r5

First public, hardware-validated release.

## Highlights

- Linux 4.9.205 built with Android Clang 9.0.8 (`r365631c`).
- PSI + memory cgroups for Android 11 userspace `lmkd`.
- legacy in-kernel Android LMK disabled.
- KSM enabled.
- 1 GiB zRAM uses LZ4 by default.
- device-scoped `vm.page-cluster=0` PHH hook documented separately.
- exact 25-name compatibility allowlist for Lenovo's stock audio/WLAN modules.
- stock boot header, command line, DTB and empty ramdisk preserved.

## Qualification

- three temporary boots and one post-flash boot;
- all 25 required vendor modules;
- Wi-Fi, audio, both cameras, touch, gestures and microphone;
- final 700 MiB / 30 s memory-pressure test;
- no OOM, kernel BUG, Oops, call trace or hung task;
- persistent boot partition readback matched the release image SHA-256.
- clean rebuild from the released inputs matched the raw `Image` SHA-256 byte for byte.

## Security notice

Lenovo's module-signing key is not public. The kernel therefore accepts modules whose key is unavailable and becomes tainted. CRC drift is restricted to 25 explicit module names, but signature enforcement is globally permissive. This release is not suitable for a security-sensitive device.

## Assets

- `tb-x505l-lowram-r5-boot.img` - bootable/flashable final image.
- `tb-x505l-lowram-r5-Image` - raw uncompressed kernel Image.
- `tb-x505l-lowram-r5-config` - exact config.
- `tb-x505l-lowram-r5-System.map` - symbol map.
- `tb-x505l-lowram-r5-Module.symvers` - build symbol versions.
- `tb-x505l-lowram-r5-compile.h` - generated build identity metadata.
- `tb-x505l-lowram-r5-source.tar.gz` - complete corresponding source with r5 applied.
- `lenovo-tb-x505l-kernel-base-6764b8e3.tar.gz` - exact public-source base used before applying the r5 patch.
- `android-clang-r365631c-linux-x86_64.tar.xz` - exact Clang prebuilt and notices.
- `aarch64-linux-android-4.9-toolchain.tar.xz` - exact GCC/binutils prebuilt and notices.
- `tb-x505l-r5-reproducibility-key.tar.gz` - deliberately public build-only key used to make the embedded certificate deterministic.
- `tb-x505l-engineering-history.tar.gz` - unsupported intermediate raw kernels, configs, symbols and sanitized logs retained for research.
- `tb-x505l-lowram-r5-artifacts.zip` - convenient bundle of public build artifacts and documentation.
- `SHA256SUMS.txt` - release checksums.

The Lenovo factory boot image and proprietary vendor binaries are not included. Back up your own device before flashing.
