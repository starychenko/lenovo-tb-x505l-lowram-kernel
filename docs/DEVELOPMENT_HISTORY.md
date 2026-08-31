# Development history and lessons learned

## 1. Device and firmware inventory

The tablet was identified through Android properties, Lenovo recovery/software-fix metadata and partition inspection as TB-X505L with an Android 10 vendor build. A full factory package and separate device backups were kept locally before kernel work began. Unique identifiers were never needed for the build and are not published.

The boot image is a 64 MiB Android boot header v1 image with no ramdisk. Its kernel payload is gzip-compressed and has an appended DTB.

## 2. Safe iteration strategy

Every candidate was tested with:

```text
fastboot boot candidate.img
```

before writing the boot partition. A normal reboot therefore restored the previous persistent boot throughout development. This mattered because the tablet's Volume Up button is unreliable.

## 3. Establishing a buildable source baseline

The stock runtime reported Linux 4.9.205 and a CAF identity matching `LA.UM.8.6.2.r1-06100-89xx.0`. The usable source state consisted of that CAF point plus Lenovo's staged device changes. The exact Git tree was frozen as `6764b8e36f9506f89cee6f1e7711cd54ae54d32b`.

Android Clang `r365631c` was selected to match the stock-era Android toolchain. A transient build later revealed that relying on PATH could silently invoke GCC, so r5 pins the absolute Clang executable and verifies `/proc/version` after boot.

## 4. Baseline boots

Initial custom kernels proved that:

- the source could produce a bootable 4.9.205 `Image`;
- MagiskBoot could preserve the stock header and DTB;
- `fastboot boot` was a reliable, non-persistent test path;
- the published source did not reproduce all stock module CRCs/signing identity.

## 5. Low-RAM feature work

PSI, memory cgroups, swap accounting, KSM and LZ4 were enabled while the legacy Android in-kernel LMK was disabled. The Android 11 GSI's `lmkd` then opened PSI monitor descriptors, proving that the new kernel interface was consumed rather than merely compiled in.

A small reclaim fix changed `isolate_lru_page(page)` to `isolate_lru_page(compound_head(page))` in the proc reclaim path.

## 6. The audio failure that changed the design

Rebuilt audio modules could be inserted, but a late PHH data hook did not produce a working ALSA card. Logs showed the real vendor audio stack normally loads during early init and participates in early hardware/ADSP probe ordering.

The solution was not another late-loader retry. It was to retain the exact Lenovo modules already on the vendor partition and make the rebuilt kernel accept their known compatibility differences.

This is the main reusable lesson: a module that loads successfully is not necessarily functionally equivalent, and Android vendor-driver ordering can be part of the hardware contract.

## 7. Narrowing the compatibility exception

An early engineering build used broad CRC overrides to prove the hypothesis. That was intentionally removed. r5 places the exception in `kernel/module.c` and checks an explicit 25-name list. All other modules keep normal version checking.

The separate signature-key problem cannot be narrowed the same way without restructuring the early signature-verification flow. r5 therefore documents the global permissive signature policy as a security limitation.

## 8. Stress and cleanup

The working design passed 700 MiB and 900 MiB pressure tests without kernel failure. Once clean boots proved that stock early-init modules worked directly, all experimental PHH late-loader files and roughly 1.5 GiB of temporary unpack/repack data were removed from the tablet.

## 9. Final r5 qualification

r5 was rebuilt with pinned Clang 9.0.8 after rejecting an accidental GCC candidate. The boot image was unpacked again to verify its raw kernel and DTB hashes. It completed repeated temporary boots, physical hardware testing, final stress testing, and then a permanent flash with full partition readback.

Obsolete candidates are not release assets because their only useful role is captured in this history.

## 10. r6 measurement before tuning

r6 kept the proven 4.9.205 source policy and compared HZ, I/O scheduler and
Android runtime-profile candidates with a native benchmark and repeated UI
workloads. The 300 Hz kernel was rejected; 100 Hz plus deadline was retained.
The Android EAS/schedutil profile stayed outside `boot.img` because Android
PowerHAL/init policy can overwrite kernel defaults and because a separate
profile has a clean uninstall path. Full results are in `R6_ENGINEERING.md`.

## 11. r7 upstream integration

r7 treated the kernel-version update as a sequence of compatibility gates:

1. merge and boot CAF 4.9.206;
2. merge CAF 4.9.227 and separate Adreno firmware from vendor-module issues;
3. merge the device line into Linux 4.9.337;
4. audit every required symbol of all 25 stock modules;
5. restore the one missing Lenovo timer helper;
6. run native, UI, pressure and hardware checks;
7. reproduce and fix the camera PM QoS lifecycle warning;
8. temporarily boot, permanently flash and hash the final boot partition.

This avoided treating a successful compile or Android home-screen appearance
as qualification. It also showed why version-number updates are not free
performance: the final CPU result was neutral, memory throughput improved, and
some storage/UI tails regressed. The complete evidence and limits are in
`R7_ENGINEERING.md`.
