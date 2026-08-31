# Changelog

## r7 / v1.2.0 - 2026-08-31

- Integrated the TB-X505L device line through CAF Linux 4.9.206 and 4.9.227
  into the KudProject Linux 4.9.337 baseline.
- Preserved the r5/r6 PSI, memory-cgroup, userspace `lmkd`, KSM, LZ4 zRAM,
  deadline and narrow 25-module compatibility design.
- Adapted the newer KGSL A6xx postamble path to the legacy shared scratch
  layout required by the shipping Adreno firmware.
- Restored the Lenovo timer helper ABI required by `pronto_wlan.ko`; the final
  audit covers 25 modules, 2,004 requirement rows and 980 unique symbols with
  zero missing kernel symbols.
- Fixed the Qualcomm camera PM QoS request lifecycle and verified repeated
  rear/front camera cycles without its previous warning or call trace.
- Compared 415 live camera vendor files against the archived S001149 factory
  vendor image; all 415 hashes matched.
- Added documented reversible Camera HAL logging profiles without patching or
  redistributing proprietary blobs.
- Ran controlled native and Android UI comparisons against the usable 4.9.227
  candidate and published both improvements and regressions.
- Completed a 700 MiB pressure run; both workers finished, with two order-0
  allocation failures recorded only at the most extreme memory point.
- Temporarily booted and then permanently flashed the final c4 image, verified
  the boot-partition SHA-256, 25 modules, core hardware, real network traffic,
  runtime memory features and a clean first-boot kernel fault scan.
- Extended and live-verified the optional crDroid 13 balanced profile on r7,
  including migration of the original r6-only boot-hook marker.
- Added the complete r7 source/config/build provenance, release helper,
  candidate history, privacy-reviewed evidence and recovery documentation.

## r6 / v1.1.0 - 2026-08-31

- Qualified the kernel on crDroid 9.10 Android 13 PHH GSI with the same stock
  Lenovo Android 10 vendor.
- Added a controlled native AArch64 benchmark for CPU, RAM, wake-up latency and
  direct sequential/random I/O.
- Added repeated Android app-launch, Settings-scroll, frame-time, `simpleperf`
  and telemetry scripts.
- Compared 100 Hz and 300 Hz candidates; retained 100 Hz after the 300 Hz build
  repeatedly worsened UI and cross-core latency tails.
- Built deadline into the final configuration after separate CFQ/deadline
  comparison and repeated Storage tests.
- Added an optional, reversible crDroid 13 EAS/schedutil profile with exact
  device/kernel guards, readback verification, local backup and clean removal.
- Measured the profile at +1.8% in warm PCMark Work 3.1 and +6.7% in the mean of
  two PCMark Storage 2.1 runs, with improved typical Settings frame latency.
- Recorded the cost proxy: about 5.6% more CPU cycles and 9-10% more context
  switches during the controlled UI workload; unplugged battery life remains a
  long-term validation item.
- Temporarily booted and then permanently flashed the final r6 image, verified
  the boot-partition SHA-256, all 25 modules, core hardware, runtime profile,
  native/UI smoke tests and a clean kernel fault scan.

## r5 / v1.0.0 - 2026-08-31

- Published a byte-for-byte reproducible build path with frozen source,
  toolchains, X.509 input, build identity and initramfs timestamp.

- Rebuilt Linux 4.9.205 with Android Clang 9.0.8 (`r365631c`).
- Enabled PSI and memory-cgroup swap accounting for Android 11 `lmkd`.
- Disabled the legacy in-kernel Android low-memory killer.
- Enabled KSM.
- Enabled LZ4 and selected it as the default zRAM compressor.
- Applied the compound-page reclaim correction in `fs/proc/task_mmu.c`.
- Added an exact 25-name Lenovo vendor-module CRC compatibility allowlist.
- Switched module signature enforcement to permissive mode because Lenovo's signing key is unavailable.
- Preserved the stock DTB, boot command line, header v1 and empty ramdisk.
- Added a TB-X505L-scoped `vm.page-cluster=0` PHH hook.
- Removed the temporary late module loader and rebuilt-module fallback after clean-boot validation.
- Qualified with temporary boot, RAM stress, physical hardware checks and post-flash boot hash verification.

## Development builds not released

- Baseline builds proved the source/toolchain/boot-image path.
- Rebuilt-module experiments exposed the early-init ordering problem for audio.
- r3 proved the complete low-RAM configuration and exact stock-module compatibility.
- r4 was rejected because it was accidentally produced with the wrong compiler path.
- r5 is the clean Clang build with the narrowed compatibility policy and is the first public release.
