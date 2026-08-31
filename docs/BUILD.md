# Reproducing the kernel build

## r8-c8 ThinLTO release-candidate build

r8-c8 uses source commit
`40a80480379791338dfacb3d8a2b3d755c655bad`, reconstructed from r8-c3 by the
ordered `patches/r8-c4-c8/` series.

```bash
export TB_X505L_BUILD_TIMESTAMP='Tue Sep 1 00:52:00 UTC 2026'
export TB_X505L_BUILD_VERSION=22
export TB_X505L_BUILD_USER=codex-r8
export TB_X505L_BUILD_HOST=tb-x505l
export TB_X505L_BUILD_JOBS=8
export TB_X505L_LDGOLD=/usr/bin/aarch64-linux-gnu-ld.gold

scripts/build-r8-candidate.sh \
  /path/to/android_kernel_lenovo_4.9.337-r8-c8 \
  /path/to/clang-r365631c \
  /path/to/aarch64-linux-android-4.9 \
  configs/tb-x505l-r8-c8-thinlto.config \
  /fresh/output/r8-c8-thinlto \
  /path/to/signing_key.pem \
  /path/to/arm-linux-androideabi-4.9
```

The final compile uses Android Clang 9.0.8 r365631c. ThinLTO linking requires
GNU gold 1.16; the helper prints and verifies the executable selected through
`TB_X505L_LDGOLD`. The older bundled gold 1.12 produced an A53 erratum warning
and is not the qualified linker.

Expected hashes:

```text
config          06571aa81ec85ee3a781d7439816859b36338ade28f00c3608acb06c893deb2f
Image           59afeab3bb758763af773b4b126158a563de89238ab1d83e4ce36757071d888c
System.map      ffe8595e6f833d872d5b90ff8252789d39647456e8d3fb79925a3326bd68338d
Module.symvers  c5c30705a62e06a5ca65c9404eac1decab8b5991186ce935fd32e5c60f13e7d9
boot.img        b0186ee9d2968051af7224802f8c040332f7672324779f3c91c7f31534d555bf
```

## r8-c3 release-candidate build

r8-c3 uses source commit
`45a98eac292f8b1fbf6f8e5b1130805691327e68`, or the exact r8-c2 source plus
`patches/tb-x505l-r8-fastpath-c3.patch`.

```bash
export TB_X505L_BUILD_TIMESTAMP='Mon Aug 31 22:30:00 UTC 2026'
export TB_X505L_BUILD_VERSION=17
export TB_X505L_BUILD_USER=codex-r8
export TB_X505L_BUILD_HOST=tb-x505l
export TB_X505L_BUILD_JOBS=8

scripts/build-r8-candidate.sh \
  /path/to/android_kernel_lenovo_4.9.337-r8 \
  /path/to/clang-r365631c \
  /path/to/aarch64-linux-android-4.9 \
  configs/tb-x505l-r8-fastpath-c3.config \
  /fresh/output/r8-fastpath-c3 \
  /path/to/signing_key.pem \
  /path/to/arm-linux-androideabi-4.9
```

Expected hashes:

```text
config          a7b9cb80d60cca83306e897647c49571033427c9ced57b36858a6b62ea996005
Image           42fb77d100dc15958e121bf7c32a1d990919cd9e2286fd4d667045d8e230c5ef
System.map      ec2dc63dd6b93fd9d76f303ef7ae3715902c728d355ca9028cc8afb48b53e8fb
Module.symvers  5844ecfc61a6dee4ec2ec2b91659a0625528b0c883fd3f6c0dfdfb5ca8226a0d
```

The helper defaults now match c3. To reproduce c2, retain the explicit c2
timestamp and build-version environment values shown below.

## r8-c2 release-candidate build

r8-c2 uses source commit `476936bf688`, or the exact r7 base
`ca9f99dcda9bc0cf55271157d3a5718ed8cf6e3b` plus
`patches/tb-x505l-r8-feature-pack-c2.patch`.

```bash
export TB_X505L_BUILD_TIMESTAMP='Mon Aug 31 19:15:00 UTC 2026'
export TB_X505L_BUILD_VERSION=16
export TB_X505L_BUILD_USER=codex-r8
export TB_X505L_BUILD_HOST=tb-x505l
export TB_X505L_BUILD_JOBS=8

scripts/build-r8-candidate.sh \
  /path/to/android_kernel_lenovo_4.9.337-r8 \
  /path/to/clang-r365631c \
  /path/to/aarch64-linux-android-4.9 \
  configs/tb-x505l-r8-feature-pack-c2.config \
  /fresh/output/r8-feature-pack-c2 \
  /path/to/signing_key.pem \
  /path/to/arm-linux-androideabi-4.9
```

Expected hashes:

```text
config          d0d68d6d28e3733840d55a452d76654b6b007cbb46793c35369015278e70cf90
Image           60ea8530b56aee8bb64fe0b35a7d6942adf70d72670da824fceed59359e3e88b
System.map      6e7ff57fdfa969b2b10ade133b2fad093e9811626094e229b804b8e7d63e0b10
Module.symvers  5844ecfc61a6dee4ec2ec2b91659a0625528b0c883fd3f6c0dfdfb5ca8226a0d
```

The seventh argument is mandatory when `CONFIG_COMPAT_VDSO=y`. The helper
refuses to silently omit the 32-bit toolchain. See `R8_ENGINEERING.md` for the
runtime validation and release-candidate limits.

## r7 release build

r7 uses the complete 4.9.337 source tree attached to v1.2.0 at commit
`ca9f99dcda9bc0cf55271157d3a5718ed8cf6e3b` and the exact config
`configs/tb-x505l-r7-upstream-4.9.337-compat-vendor.config`.

```bash
export TB_X505L_BUILD_TIMESTAMP='Mon Aug 31 10:45:00 UTC 2026'
export TB_X505L_BUILD_VERSION=14
export TB_X505L_BUILD_USER=codex-r7
export TB_X505L_BUILD_HOST=tb-x505l
export TB_X505L_BUILD_JOBS=8

scripts/build-r7-candidate.sh \
  /path/to/android_kernel_lenovo_4.9.337 \
  /path/to/clang-r365631c \
  /path/to/aarch64-linux-android-4.9 \
  configs/tb-x505l-r7-upstream-4.9.337-compat-vendor.config \
  /fresh/output/4.9.337-compat-vendor-c4 \
  /path/to/signing_key.pem
```

Expected release hashes:

```text
config          ddb6b6277eedc4f0c45c55a2196d1fb5ffb1fe15409e86a4568124d099845fac
Image           2ddcf2b84d3b4e5588d3ab43c7ac4835c0249c57e2a6e01d0ec665d074ba6de1
System.map      2cc922803e61f6eeb526736ac8a1cd206ea0811eb9dd19aef8cec1892ccddc5f
Module.symvers  5844ecfc61a6dee4ec2ec2b91659a0625528b0c883fd3f6c0dfdfb5ca8226a0d
```

The helper verifies Linux 4.9.337, the exact r7 local version, the narrow
vendor-module policy and the camera PM QoS lifecycle fix before building. It
defaults to eight jobs to bound build memory. Raising the job count changes
resource use, not the documented build identity, but should be done only when
the host has sufficient RAM.

The exact original build paths were:

```text
source  /home/evgen/tb-x505l-r7/git/android_kernel_lenovo_4.9.337
output  /home/evgen/tb-x505l-r7/build/4.9.337-compat-vendor-c4
clang   /home/evgen/tb-x505l-r6/toolchains/clang-r365631c
gcc     /home/evgen/tb-x505l-r6/toolchains/aarch64-linux-android-4.9
```

Legacy Android kernel objects embed absolute paths, so use those paths when a
byte-identical `Image` is required. Another path should produce a functionally
equivalent image but is not promised to have the same SHA-256. The release
source archive omits `.git`; the helper accepts both that archive and a Git
checkout.

r7 reuses the public project signing key archived with v1.1.0. Its PEM SHA-256
is `49ec24024920789b0c6d7a47c5151857f56941dfd57a9eb73b37f12e0e1591a6`.
It is a reproducibility input, not Lenovo's private production key or a user
credential. The exact toolchain archives remain on v1.0.0.

The r6/r5 instructions below remain available to reproduce the older releases.

## r6 release build

r6 uses the same patched source commit and public reproducibility key as r5.
Its final config is `configs/tb-x505l-lowram-r6.config`. The only functional
kernel-config change from r5 is deadline support/default selection; the local
version also changes to `-tbx505l-r6`.

```bash
export TB_X505L_BUILD_TIMESTAMP='Mon Aug 31 11:45:00 UTC 2026'
export TB_X505L_BUILD_VERSION=7

scripts/build-r6-candidate.sh \
  /path/to/patched-r5-source \
  /path/to/clang-r365631c \
  /path/to/aarch64-linux-android-4.9 \
  configs/tb-x505l-lowram-r6.config \
  /fresh/output/r6-final \
  /path/to/signing_key.pem
```

Expected release hashes:

```text
config          055df656f6cbfaf33afa7c61153e537b96d3772181e078ff52c7501b21969353
Image           974d7ce683b25252743901f618cbb1024a66080ee684ba507dcbac657329f886
System.map      0d35d8c0ca2f435799f9fdd515df7293b79b9fd8bd788637ec44be7839b3ecda
Module.symvers  7c74085e951663ba6185e7576a59f62f3faa0157d86d0001aac494d428e2614e
```

The r5 instructions below remain the source/provenance basis and reproduce the
original v1.0.0 artifact.

## Exact inputs

- Either the complete corresponding source archive from the r5 release, or the
  exact base archive plus `patches/tb-x505l-lowram-r5.patch` from this repository.
- `configs/tb-x505l-lowram-r5.config`.
- Android Clang 9.0.8 build `r365631c`.
- AArch64 Android GCC 4.9 cross-toolchain for binutils.
- `signing_key.pem` from `tb-x505l-r5-reproducibility-key.tar.gz` when an
  exact byte-for-byte result is required.
- Linux or WSL2 with GNU make, Python 3, Perl, bc, bison, flex, OpenSSL development headers and standard kernel-build utilities.

Build identity:

```text
Linux 4.9.205-perf+
KBUILD_BUILD_USER=codex-lowram
KBUILD_BUILD_HOST=tb-x505l
KBUILD_BUILD_VERSION=5
KBUILD_BUILD_TIMESTAMP=Sun Aug 30 21:18:08 UTC 2026
```

The timestamp, build number and local-version suffix are pinned because they are
embedded into the kernel and affect the final hash. The helper also regenerates
the empty built-in initramfs with its historical cpio timestamp
`Sun Aug 30 19:02:44 UTC 2026` before compiling the final kernel. The boot image
still has a zero-length Android ramdisk; this is a tiny built-in kernel archive
containing only the default device nodes.

## Prepare the source

The release's complete source archive already contains the r5 modifications and config for license compliance. To reproduce the original development path from the exact Lenovo base archive instead:

```bash
tar -xzf lenovo-tb-x505l-kernel-base-6764b8e3.tar.gz
cd android_kernel_lenovo-q-205
git apply /path/to/tb-x505l-lowram-r5.patch
mkdir -p out-lowram
cp /path/to/tb-x505l-lowram-r5.config out-lowram/.config
```

The patch was validated both in reverse against the build tree and forward against a fresh extraction of the base tree.

## Exact build command

```bash
env \
  KBUILD_BUILD_USER=codex-lowram \
  KBUILD_BUILD_HOST=tb-x505l \
  KBUILD_BUILD_VERSION=5 \
  KBUILD_BUILD_TIMESTAMP='Sun Aug 30 21:18:08 UTC 2026' \
  make O=out-lowram \
  ARCH=arm64 \
  SUBARCH=arm64 \
  LOCALVERSION=+ \
  HOSTCFLAGS=-fcommon \
  CC=/opt/android/clang-r365631c/bin/clang \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  CROSS_COMPILE=/opt/android/aarch64-linux-android-4.9/bin/aarch64-linux-android- \
  -j8 Image
```

Adjust only the toolchain locations. The helper [scripts/build-kernel.sh](../scripts/build-kernel.sh) accepts those locations as arguments and preserves the remaining build identity.

For the exact released hash, unpack the complete source as
`/home/evgen/android_kernel_lenovo-q-205`, use
`/home/evgen/android_kernel_lenovo-q-205/out-lowram` as `O=`, and pass the
release's `signing_key.pem` as the helper's fifth argument:

```bash
scripts/build-kernel.sh \
  /home/evgen/android_kernel_lenovo-q-205 \
  /opt/android/clang-r365631c \
  /opt/android/aarch64-linux-android-4.9 \
  /home/evgen/android_kernel_lenovo-q-205/out-lowram \
  /path/to/signing_key.pem
```

This legacy tree embeds absolute source/output paths in many compiled strings.
A different path produces a functionally equivalent kernel but not the same
bytes. The configuration also embeds an X.509 certificate; without the archived
build key, OpenSSL creates a new key pair and changes the binary. See
[reproducibility/README.md](../reproducibility/README.md).

Expected raw `Image` SHA-256:

```text
4d543f6c817aa11528489338a01e7e7c9158223ead52a2db165d9964bfba3779
```

If the hash differs, inspect `include/generated/compile.h`, compiler version, config hash and source patch before packaging.

## Why `Image`, not all DTBs

The source tree contains unrelated Qualcomm/Lenovo DTB targets that do not all build cleanly in this environment. The tablet release deliberately reuses the exact DTB extracted from its verified boot image. The qualified target is therefore `Image`; a blanket `make` failure in unrelated `sdm429-spyro*.dtb` targets is not ignored when producing a new DTB, because this project does not produce one.

## Build-time compatibility changes

Two patch sections are build-only:

- unsupported warning switches are wrapped with `cc-disable-warning`;
- the legacy Qualcomm `gcc-wrapper.py` is ported from Python 2 to Python 3.

These changes do not alter runtime policy.

## Repacking the boot image

The tested boot format is:

```text
header version: 1
page size: 2048
OS version: 10.0.0
OS patch level: 2021-12
ramdisk size: 0
kernel format: gzip
stock DTB size: 4218223 bytes
final image size: 67108864 bytes
```

MagiskBoot was used on the ARM64 tablet because it preserves the stock header, separates the appended DTB, recompresses the replacement `Image` in the original format and repacks a fixed-size boot image. MagiskBoot is not bundled here; obtain it from the official [Magisk repository](https://github.com/topjohnwu/Magisk).

The helper [scripts/repack-boot-on-device.ps1](../scripts/repack-boot-on-device.ps1) documents and automates the exact sequence. Always repack from your own matching boot image.
