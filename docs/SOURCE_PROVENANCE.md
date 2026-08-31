# Source provenance

## Exact development base

The source checkout was intentionally frozen at two levels:

- CAF metadata commit: `4e699d80a1f43d3dd380d1c7a50cc8fa0ee30440`
- CAF tag: `LA.UM.8.6.2.r1-06100-89xx.0`
- exact staged Lenovo source tree: `6764b8e36f9506f89cee6f1e7711cd54ae54d32b`

The staged tree matters. Checking out only the CAF commit does not reproduce the Lenovo device source.

The public reference repository used during investigation is:

```text
https://github.com/Lenovo-TB-X505X/android_kernel_lenovo_TB-X505X
```

Its branches were useful for comparison, but the r5 release uses the exact archived tree above rather than assuming that a moving branch remains identical.

## Project modifications

The release patch changes exactly five tracked files relative to the frozen base:

```text
Makefile
drivers/block/zram/zram_drv.c
fs/proc/task_mmu.c
kernel/module.c
scripts/gcc-wrapper.py
```

The patch applies cleanly to a fresh base extraction. Copies of the modified files are not required to rebuild because the complete source release already contains them.

## Configuration

The final config hash is:

```text
f9ad24525e98e579474ab7a3b0b5037646fd90aa113a27eed9275e64cd1c4cf5
```

The meaningful config delta is limited to PSI, memory cgroups/swap, KSM, disabling legacy Android LMK, and enabling LZ4 compression/decompression support.

## Toolchain identity

```text
Android (5900059 based on r365631c) clang version 9.0.8
CLANG_TRIPLE=aarch64-linux-gnu-
CROSS_COMPILE=aarch64-linux-android-4.9/bin/aarch64-linux-android-
```

Build user, host and timestamp are pinned in [BUILD.md](BUILD.md).

The release also archives both exact prebuilt toolchain directories, including
their original `NOTICE`, license, version and manifest files. The build therefore
does not depend on those prebuilts remaining available from a moving upstream
branch.

## Release source archive

The GitHub Release includes a complete corresponding source tarball rather than only a link to an external branch. It includes:

- the frozen Lenovo/CAF source state;
- all r5 changes already applied;
- the exact r5 config;
- build and provenance documentation.

The tarball checksum is listed in the release `SHA256SUMS.txt`.

Before publication, that archive was extracted into a fresh directory, the r5
patch was applied independently, and the public build helper reproduced raw
`Image` SHA-256
`4d543f6c817aa11528489338a01e7e7c9158223ead52a2db165d9964bfba3779`
exactly. The two initially hidden inputs - legacy absolute build paths and the
timestamp of the empty built-in initramfs - are documented in [BUILD.md](BUILD.md).
