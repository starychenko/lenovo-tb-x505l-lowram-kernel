# Changelog

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
