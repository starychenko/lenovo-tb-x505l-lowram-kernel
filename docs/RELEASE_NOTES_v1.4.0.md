# v1.4.0 - final r8-c9 kernel

This is the final v1.4.0 release for the tested Lenovo TB-X505L 2/32 GB. It
promotes the complete r8 c2-c8 scheduler, KGSL, ARM64, memory, BFQ, power and
A53 ThinLTO work, then adds the qualified c9 CPU/GPU device-tree changes.

## Final c9 changes

- Raises the lowest CPU level from 960 to 1305.6 MHz. The qualified maximum
  remains 2016 MHz.
- Adds a real measured 364.5 MHz GPLL3 GPU level above the retained 320 MHz
  fallback, with the next validated voltage corner and matching bus votes.
- Keeps `deadline` as the default eMMC scheduler; BFQ remains selectable.
- Keeps the same Android Clang 9.0.8, GNU gold 1.16 ThinLTO build and the
  narrow 25-name Lenovo vendor-module compatibility policy qualified in c8.

Five repeated off-screen EGL/GLES runs averaged 14.463 FPS versus the
12.702 FPS 320 MHz baseline, a 13.86% gain in that specific workload. A
600-frame run and mixed four-thread CPU/GPU stress completed at approximately
14.46-14.50 FPS with a 54 C peak. The GPU branch clock measured approximately
364.498-364.503 MHz under load.

The final 25-module ABI audit covered 2107 symbol requirements with zero CRC
drift, zero candidate regressions and zero unresolved symbols. The image also
passed temporary boot, hardware and production-profile checks, was flashed
permanently, and matched the live boot-partition readback byte for byte:

```text
773611c66e7458529446c05aa974c25d4c4cef8a7d49329af40bd3ea1f75b4ce
```

## Scope and installation

The release was physically tested only on one TB-X505L 2/32 GB with Lenovo
vendor `TB-X505L_S001149_221018_ROW` and crDroid 9.10 PHH GSI, Android 13.
It is not a generic image for X505F, X505X or another vendor build.

Back up your own boot partition, verify `SHA256SUMS.txt`, and use
`fastboot boot` before any permanent flash. Test Wi-Fi, audio, cameras,
Bluetooth, touch, accelerometer, suspend/resume and charging on your own unit.
The v1.4.0-rc1 c8 image and v1.2.0 r7 image remain available as rollback
points for the exact tested vendor.

## Reproducibility and evidence

- Final source commit:
  `0ea8dc3e34140ac48640f23dacf8b9a04fd2b26e`
- Reconstructed source tree:
  `88f8929f885b45ec856f746a0a3f350efc1d40de`
- Incremental c9 patch SHA-256:
  `a460e2db9ec83def84705bf486f2edc98b23fbf75771a65da526912665c2a2dc`
- Full c9 source archive SHA-256:
  `6da1e067eca9f5a64789bbd8759591c97c9e93ce063cf7606da67e8cda015c74`

The release includes the boot image, raw Image, exact config, patched DTB,
`System.map`, `Module.symvers`, generated `compile.h`, complete source archive,
ordered c4-c9 patch series, benchmark tool and curated validation evidence.
The clock-source investigation and rejected 400/432/540 MHz candidates are
documented in `docs/GPU_OVERCLOCK.md`; those candidates are not flashable
release images.
