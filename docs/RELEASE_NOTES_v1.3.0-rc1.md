# v1.3.0-rc1 - r8 feature-pack candidate c2

This pre-release is the first integrated r8 development candidate for the
Lenovo TB-X505L 2/32 GB. It keeps the qualified Linux 4.9.337 r7 base and adds:

- dedicated Binder slab caches with complete initialization cleanup;
- a real AArch32 compat vDSO backport and separate ARM32 build toolchain;
- built-in BBR, Westwood, FQ and FQ-CoDel support;
- KCAL controls for the MDSS MDP v1.7 display path;
- a reusable active runtime validator that restores changed state.

The candidate completed temporary boot, 25-module/audio/Wi-Fi/camera/sensor/
Bluetooth checks, live 32-bit vDSO validation, network/KCAL exercises, two
native smoke repetitions, Android UI smoke tests and a concurrent 512 MiB
memory-pressure run. The final kernel fault scan was clean.

It has not replaced the permanently installed r7 image. Test with
`fastboot boot` first. Do not flash it on TB-X505F, TB-X505X, another vendor
build or a device without a verified boot backup.

No GPU overclock is included. The tested tablet is QFPROM speed bin 10 and its
validated GPU level is 320 MHz.

See `docs/R8_ENGINEERING.md` for hashes, source identity, tests and limits.
