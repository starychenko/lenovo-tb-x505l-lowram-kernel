# Changelog

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
