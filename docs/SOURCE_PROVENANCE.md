# Source provenance

## r8-c2 source delta

r8-c2 starts from the complete, already archived v1.2.0 source at
`ca9f99dcda9bc0cf55271157d3a5718ed8cf6e3b` and ends at development commit
`476936bf688`.

The public consolidated patch and exact config are sufficient to reconstruct
the c2 source from the archived r7 base without depending on a moving donor
branch. The main compatible donor was
`https://github.com/mi-sdm439/android_kernel_xiaomi_sdm439`; individual commit
authorship remains in the r8 development history. The vDSO32 dependency series
also traces back to Android/common and upstream arm64 work.

No Lenovo firmware, vendor module, APK, device DT backup, serial/PSN data or
private key was added to the patch or Git repository. The project
reproducibility key is the same public build input already archived with the
older releases; it is not Lenovo's production key.

## r7 final source

The v1.2.0 source archive is the complete working tree at:

```text
branch  r7-upstream-4.9.337-merge
commit  ca9f99dcda9bc0cf55271157d3a5718ed8cf6e3b
tree    generated from that clean commit; .git metadata excluded from the tarball
```

Its first parent line comes from KudProject's public `kernel_msm-4.9`
repository at Linux 4.9.337 commit
`cad7430de0364a908d73cea93d06f9ca44ad439e`. The second parent line carries
the exact TB-X505L device source and low-RAM changes through CAF 4.9.206 and
4.9.227.

The integration commits are recorded in [R7_ENGINEERING.md](R7_ENGINEERING.md).
Three small post-merge compatibility commits provide the legacy KGSL scratch
layout, Lenovo timer helper ABI and camera PM QoS lifecycle fix. The release
archive contains their resulting full source, so rebuilding does not depend on
either donor repository remaining online.

## Original Lenovo development base

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

## r5/r6 project modifications

The release patch changes exactly five tracked files relative to the frozen base:

```text
Makefile
drivers/block/zram/zram_drv.c
fs/proc/task_mmu.c
kernel/module.c
scripts/gcc-wrapper.py
```

The patch applies cleanly to a fresh base extraction. Copies of the modified files are not required to rebuild because the complete source release already contains them.

## r5/r6 configuration

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

Build user, host and timestamp are pinned separately for r5/r6/r7 in
[BUILD.md](BUILD.md).

The release also archives both exact prebuilt toolchain directories, including
their original `NOTICE`, license, version and manifest files. The build therefore
does not depend on those prebuilts remaining available from a moving upstream
branch.

## Release source archives

Each GitHub Release includes a complete corresponding source tarball rather
than only a link to an external branch. The r5/r6 source includes:

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

The v1.2.0 archive independently preserves the final 4.9.337 tree at
`ca9f99dc...`. Its exact config SHA-256 is
`ddb6b6277eedc4f0c45c55a2196d1fb5ffb1fe15409e86a4568124d099845fac`.
It was created with `git archive` directly from that clean commit. Its checksum
is included in the release `SHA256SUMS.txt`.

No `.git` object database, build output, Lenovo firmware, proprietary module or
device backup is placed in the source archive. Git commit IDs and the full
integration graph are preserved in the documentation; the corresponding final
source files are preserved in the archive itself.
