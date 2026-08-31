# r8 engineering: first integrated feature pack

## Status and scope

r8-c2 is the first development candidate built on the qualified r7 Linux
4.9.337 base. It deliberately groups several independent, low-risk features
into one build-and-test cycle while keeping each source change as a separate
Git commit.

The candidate was loaded with `fastboot boot`; it has not replaced the
permanently installed r7 image. A normal reboot still returns the tested tablet
to r7. This is an engineering release candidate, not a claim that every future
r8 change should be enabled by default.

Source identity:

```text
r7 base       ca9f99dcda9bc0cf55271157d3a5718ed8cf6e3b
r8-c2 head    476936bf688
config        d0d68d6d28e3733840d55a452d76654b6b007cbb46793c35369015278e70cf90
source patch  b543bd902b5a72308f3300dc762827fad40710c2ab04f32558f36d6f0fa4bb4a
```

The consolidated patch applies forward to the exact r7 base and in reverse to
the r8-c2 head. It contains 40 changed files, 2,394 insertions and 513
deletions. The full commit history remains in the development source checkout.

## What is in c2

### Binder allocation caches

Frequently allocated Binder objects now use dedicated slab caches:

- buffer metadata;
- node;
- process;
- reference and death notification;
- thread;
- transaction;
- work item.

The implementation was adapted from the compatible SDM439 donor tree and adds
complete reverse-order cleanup if any cache or shrinker initialization step
fails. On the live tablet all eight logical Binder caches were present, and the
kernel recorded more than 100,000 Binder transactions during qualification.
SLUB may merge caches with identical layouts; that is expected and does not
disable the logical cache API.

### AArch32 compat vDSO

r8 backports the complete arm64 compat-vDSO dependency series rather than only
turning on a Kconfig symbol. The build uses a separate ARM32 GCC 4.9 toolchain
and produces an ELF32 ARM EABI5 shared object containing:

```text
__vdso_clock_gettime
__vdso_gettimeofday
__vdso_clock_getres
```

The live check found ten 32-bit Android/vendor processes with a mapped
`[vdso]`, including the camera provider, DRM server, OMX service and
`app_process32`. `CONFIG_ARM_ARCH_TIMER_VCT_ACCESS=y` permits the fast timer
path for compatible AArch32 applications.

### Network queueing and congestion control

The candidate builds in:

```text
CONFIG_TCP_CONG_BBR=y
CONFIG_TCP_CONG_WESTWOOD=y
CONFIG_NET_SCH_FQ=y
CONFIG_NET_SCH_FQ_CODEL=y
```

Both combinations were exercised on the live Wi-Fi interface:

- FQ-CoDel + BBR;
- FQ + Westwood.

Each accepted real Internet traffic with zero packet loss in the short smoke
test. The validator then restored the original `cubic`, `mq` and
`pfifo_fast` state. r8-c2 does not silently change the device's default qdisc
or TCP algorithm: a loaded feature is not yet evidence that it is the best
default for this multiqueue Wi-Fi driver.

### KCAL display controls

KCAL is built into the MDSS MDP v1.7 display path. The live sysfs interface
exposes RGB, minimum RGB, saturation, hue, value, contrast and enable state.
Qualification read every attribute and performed no-op writes to all safely
writable values; the values were read back unchanged.

KCAL is a control interface, not an automatic color profile. The release does
not alter the owner's current display calibration.

## GPU speed-bin finding

No GPU overclock is included. The live device tree contains higher Adreno 504
levels for other silicon bins, but the tested tablet's QFPROM values decode to
speed bin 10:

```text
QFPROM 0x6004 = 0x98800003
QFPROM 0x6008 = 0x3d000416
speed bin      = 10
validated GPU  = 320 MHz
```

For this bin the stock DT exposes only 320 MHz plus the XO level. The 400, 510,
560 and 650 MHz tables belong to other bins. A future 400 MHz experiment must
therefore be an explicitly labelled overclock candidate with thermal, GPU and
long-duration stability tests; it must not become the default r8 profile.

## Build identity

```text
Linux localhost 4.9.337-tbx505l-r8-feature-pack-c2+ #16 SMP PREEMPT
Mon Aug 31 19:15:00 UTC 2026 aarch64
```

```text
boot.img       d7df0e2c509802120118f3995938fb5e578cd454405d32a945d86367469c45ad
Image          60ea8530b56aee8bb64fe0b35a7d6942adf70d72670da824fceed59359e3e88b
config         d0d68d6d28e3733840d55a452d76654b6b007cbb46793c35369015278e70cf90
System.map     6e7ff57fdfa969b2b10ade133b2fad093e9811626094e229b804b8e7d63e0b10
Module.symvers 5844ecfc61a6dee4ec2ec2b91659a0625528b0c883fd3f6c0dfdfb5ca8226a0d
```

The raw `Image` hash remained identical after the vDSO warning-probe and KCAL
whitespace cleanups were committed and the affected objects were rebuilt with
the same pinned build identity. The boot image preserves the r7/Lenovo header,
command line, empty Android ramdisk and stock DTB; only the kernel payload is
replaced.

Toolchains:

```text
Clang        Android r365631c, 9.0.8
AArch64 GCC Android 4.9
ARM32 GCC   Android 4.9 pie-release, commit cb7b3ac
```

The public r8 helper requires the ARM32 toolchain whenever
`CONFIG_COMPAT_VDSO=y`; it refuses to continue if that input is missing.

## Automated runtime qualification

`scripts/validate-r8-feature-pack.ps1 -ActiveTests` now automates the complete
feature-pack regression pass. It preserves and restores the initial TCP,
qdisc and Bluetooth state even when a test fails.

The final run passed every check:

| Area | Result |
|---|---|
| Android boot | complete |
| Lenovo vendor modules | 25/25 loaded |
| Audio | `sdm439-snd-card-mtp` present |
| Wi-Fi | interface up and real traffic passed |
| Cameras | two devices reported |
| Accelerometer | MC34XX present and active |
| Bluetooth | OFF -> ON -> OFF completed |
| compat vDSO | 10 live 32-bit mappings |
| Binder | all 8 logical caches present |
| KCAL | nodes present; safe no-op writes restored |
| FQ/FQ-CoDel | both attached successfully |
| BBR/Westwood | both selected and carried traffic |
| Kernel fault scan | clean |

The privacy-reviewed output is stored in
`benchmarks/results/r8-c2/runtime-validation.txt`.

## Controlled stress and UI smoke tests

Two simultaneous 256 MiB memory workers completed 16 rounds each. The minimum
sampled `MemAvailable` was 31,472 KiB, PSI pressure became visible, and memory
recovered after the workers exited. There was no OOM kill, kernel fault or
vendor-module loss.

The native smoke test completed two repetitions of single-thread CPU,
four-thread CPU, 64 MiB memory, same/cross-core wake-up latency and 64 MiB
direct sequential/random I/O. It is regression evidence, not a performance
comparison with r7 because no matched r7 control was run in this cycle.

Five cold-process launches per application produced these medians:

| App | Median |
|---|---:|
| NewPipe | 1,446 ms |
| Cromite | 805 ms |

Two Settings scroll samples produced 0.16% median jank over 620 median frames.
The curated raw summaries are in `benchmarks/results/r8-c2/`.

## Evidence limits

- Only one TB-X505L 2/32 GB unit, one Lenovo vendor build and one crDroid/PHH
  Android 13 system were exercised.
- r8-c2 was temporary-booted, not permanently flashed.
- Automated checks prove service/device presence and exercised kernel paths;
  they do not replace the owner's final physical touch, display, camera,
  microphone and long-duration battery check.
- The network smoke test proves availability and basic operation, not that BBR
  or either qdisc improves every Wi-Fi or LTE workload.
- KCAL and additional congestion algorithms add optional controls; they do not
  make the tablet faster by themselves.
- Linux 4.9 and the Android 10 vendor security level remain old.

## Next development package

The next low-risk wave should focus on measurable scheduler, reclaim and I/O
latency improvements. Each candidate should be compared against this c2 state
with the same native, UI, pressure and feature-regression harness. ThinLTO,
major scheduler replacement and GPU overclocking remain isolated experiments
because they have materially larger boot, ABI, thermal or stability risk.

## Donor and upstream references

- [Compatible SDM439 donor tree](https://github.com/mi-sdm439/android_kernel_xiaomi_sdm439)
- [Android common-kernel documentation](https://source.android.com/docs/core/architecture/kernel/android-common)
- [Linux FQ-CoDel documentation](https://www.kernel.org/doc/html/latest/networking/sch_fq_codel.html)
- [Google BBR source and documentation](https://github.com/google/bbr)
