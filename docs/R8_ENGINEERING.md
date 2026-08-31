# r8 engineering: feature pack and fast-path candidate

## Current status

`r8-c8-thinlto` is the current qualified r8 candidate for the tested Lenovo
TB-X505L 2/32 GB. It keeps the c2/c3 feature pack and adds 17 reviewable
scheduler, KGSL, ARM64, memory, BFQ, power and compiler commits. c8 completed
temporary boot, repeated targeted tests, memory pressure, production-profile
and hardware qualification, was then flashed permanently, and its
boot-partition readback matched the tested image byte for byte.

It remains a pre-release because the project has only one physical test unit
and no long-duration unplugged battery or multi-device sample. The stable
fallback remains r7/v1.2.0.

Source identity:

```text
r7 base       ca9f99dcda9bc0cf55271157d3a5718ed8cf6e3b
r8-c2 head    476936bf688557fb6edbe87ef7f0c4acc91592c6
r8-c3 head    45a98eac292f8b1fbf6f8e5b1130805691327e68
r8-c8 head    40a80480379791338dfacb3d8a2b3d755c655bad
c2 patch      b543bd902b5a72308f3300dc762827fad40710c2ab04f32558f36d6f0fa4bb4a
c3 patch      93d3de2d1dd607b18d03259235c9ca67f4d21f1f8d9e63a4cb34bd9726be15ef
```

The c2 patch reconstructs the feature pack from the exact r7 base. The c3
patch then applies four files, 32 insertions and three deletions on top of c2.
Both deltas were checked in the forward and reverse directions.
The c4-c8 mail series was applied to the c3 tree in a temporary Git index; its
resulting tree ID exactly matched c8 without creating a second full worktree.

## What c2 introduced

### Binder allocation caches

Frequently allocated Binder objects use dedicated slab caches for buffer
metadata, nodes, processes, references, death notifications, threads,
transactions and work items. Initialization has complete reverse-order cleanup
on failure. All eight logical caches were present on the live tablet.

### AArch32 compat vDSO

r8 backports the complete arm64 compat-vDSO dependency series and builds its
32-bit object with a separate ARM32 GCC 4.9 toolchain. Ten live 32-bit Android
and vendor processes had a mapped `[vdso]` during validation. The image exports
the compat clock/gettimeofday entry points rather than forcing every call
through the kernel syscall path.

### Network and display controls

BBR, Westwood, FQ and FQ-CoDel are built in and selectable. Both FQ-CoDel +
BBR and FQ + Westwood carried real traffic in the reversible validator. The
existing `cubic`, multiqueue and `pfifo_fast` defaults are retained because a
smoke test is not proof that another policy is universally better for this
Wi-Fi driver.

KCAL is integrated into the MDSS MDP v1.7 path. RGB, minimum RGB, saturation,
hue, value, contrast and enable state were read and exercised with safe no-op
writes. No color calibration is silently imposed.

## What c3 adds

### Scheduler sync-wake placement

The scheduler now keeps a synchronous wake-up on the waker CPU only when that
CPU is allowed, has enough capacity and is about to become idle. This avoids
blindly stacking a wakee on an already busy CPU while preserving the cheap
same-CPU path when it is actually useful.

### Bounded high-order reclaim

When compaction can already satisfy a high-order allocation, `kswapd` no
longer continues reclaiming ordinary pages only to meet the original
high-order target. The intent is to reduce unnecessary reclaim and cache loss
on a 2 GB device.

### Unevictable-page compaction default

`vm.compact_unevictable_allowed` now defaults to `0`. Compaction therefore
does not scan mlocked/unevictable pages unless userspace explicitly opts in.
The production validator confirms the live value.

### Small I2C transfer path

Qualcomm I2C v2 uses block mode for transfers below 96 bytes instead of paying
DMA setup overhead. The live Goodix touchscreen is on this exact
`gt9xx`/`MSM-I2C-v2` path. The donor commit estimates a 0.5-1 ms reduction for
small touch transactions; this project verified the hardware path and touch
operation, not that sub-millisecond number with an external latency rig.

The four changes are kernel-native and active from kernel boot. They are not
Android init scripts.

## What c4-c8 add

### Scheduler and KGSL submission

The scheduler avoids pulling utilization from a CPU with no useful migratable
task. KGSL now protects the critical ioctl path from deep CPU idle while it
waits, removes unused ringbuffer timing, raises the critical workqueue priority
and moves selected workers to the modern kthread-worker API.

### ARM64 and memory hot paths

The candidate imports optimized arm64 `memcmp` and `strlen` implementations
and the large-region `mremap` fast path. These are targeted code paths, not a
claim that every application receives the donor commit headline.

### BFQ without changing the default

BFQ v8r10 is built in and can be selected at runtime. The live scheduler list
is `noop [deadline] cfq bfq`; `deadline` stays selected because the short BFQ
functional test proves compatibility, not a universal gain on this eMMC.

### SDM429 power vote

The stock device tree requests a 360 us KGSL active latency, which prevented
the generic relaxed value from taking effect. The SDM429-specific override is
1000 us active/CPU-mask and 100 us wake latency. The critical ioctl guard still
uses the low-latency path. The live active node reads back `1000`.

### A53 ThinLTO build

The final c8 build enables optimized inlining, tunes generated arm64 code for
Cortex-A53 with the live AES/SHA/CRC feature set, and uses ThinLTO. It keeps
Android Clang 9.0.8 r365631c; only the LTO link uses system GNU gold 1.16
instead of the older bundled gold 1.12. The compressed kernel grows by about
1.2 MiB, so c8 accepts a measured latency/size trade-off rather than claiming
that LTO is free.

All 25 shipping modules were audited across 2,004 requirement rows and 980
unique symbols: zero missing symbols and zero CRC drift.

## Android runtime policy

The separate crDroid/PHH balanced profile controls Android-owned scheduler and
`schedutil` nodes. Those nodes are created or rewritten by Android init and
PowerHAL, so baking the same values into an early kernel default would not make
the final policy deterministic.

The installer now positions its hook before PHH's unrelated 30-second cleanup
delay. The hook applies when every policy node is writable and reapplies five
seconds after `sys.boot_completed`. This is PHH's boot-hook mechanism - similar
in purpose to `init.d`, but it is not classic `init.d` and it does not run in
the first seconds of kernel startup.

The profile also restores `kernel.sched_schedstats=0` after Android's
`atrace.rc` enables continuous scheduler accounting. A live c2 A/B check found
roughly 7-9% lower cross-core mean wake latency and about 2% lower loaded p95,
without a measurable one-thread throughput loss. Compiling scheduler stats out
was rejected because it changed hundreds of exported CRCs; the runtime switch
keeps the vendor-module ABI unchanged and remains reversible.

Production values:

```text
top-app boost / prefer_idle       10 / 1
foreground boost / prefer_idle     5 / 1
schedutil hispeed_freq / load       1497600 / 75
schedutil up/down rate limit us      0 / 20000
kernel.sched_schedstats              0
```

## GPU speed-bin result

No GPU overclock is included. The live device tree contains higher Adreno 504
levels for other silicon bins, but the tested tablet's QFPROM values decode to
speed bin 10:

```text
QFPROM 0x6004 = 0x98800003
QFPROM 0x6008 = 0x3d000416
speed bin      = 10
validated GPU  = 320 MHz
```

The 400, 510, 560 and 650 MHz tables belong to other bins. A 400 MHz build
would be an explicit overclock experiment requiring thermal and long-duration
3D validation, not a safe default.

## c3 build identity

```text
Linux localhost 4.9.337-tbx505l-r8-fastpath-c3+ #17 SMP PREEMPT
Mon Aug 31 22:30:00 UTC 2026 aarch64
```

```text
boot.img       55ecbf9981f1c6cb0327053274654d33ca7e1a4e6f2b9cdf84648e7e0ce0d76c
Image          42fb77d100dc15958e121bf7c32a1d990919cd9e2286fd4d667045d8e230c5ef
config         a7b9cb80d60cca83306e897647c49571033427c9ced57b36858a6b62ea996005
System.map     ec2dc63dd6b93fd9d76f303ef7ae3715902c728d355ca9028cc8afb48b53e8fb
Module.symvers 5844ecfc61a6dee4ec2ec2b91659a0625528b0c883fd3f6c0dfdfb5ca8226a0d
```

The c3 config differs from c2 only by `CONFIG_LOCALVERSION`. Its
`Module.symvers` is byte-identical to c2. The full shipping-module audit covers
25 modules, 2,004 required-symbol rows and 980 unique symbols with zero missing
symbols and zero CRC drift.

The boot image retains the tested Lenovo header, command line, empty Android
ramdisk and stock DTB; only the kernel payload changes.

## Qualification result

The final production run passed:

| Area | Result |
|---|---|
| Android boot | complete after cold and permanent boot |
| Permanent image | boot-partition readback equals c3 SHA-256 |
| Lenovo vendor modules | 25/25 loaded |
| Audio / Wi-Fi | card present / interface up and real traffic |
| Camera / sensor | two cameras and active MC34XX accelerometer |
| Bluetooth | OFF -> ON -> restored OFF |
| compat vDSO | 10 live 32-bit mappings |
| Binder / KCAL | all logical caches and every expected node present |
| Network options | FQ/FQ-CoDel and BBR/Westwood exercised |
| c3 paths | compact default and Goodix I2C path verified |
| Runtime profile | all nine values read back after post-boot pass |
| Kernel fault scan | clean |

Two simultaneous 256 MiB memory workers completed 16 rounds each without an
OOM kill, panic or hung task. Curated evidence is in
`benchmarks/results/r8-c3/`.

## c8 build and qualification

```text
Linux localhost 4.9.337-tbx505l-r8-c8-thinlto+ #22 SMP PREEMPT
Tue Sep 1 00:52:00 UTC 2026 aarch64
```

```text
boot.img       b0186ee9d2968051af7224802f8c040332f7672324779f3c91c7f31534d555bf
Image          59afeab3bb758763af773b4b126158a563de89238ab1d83e4ce36757071d888c
config         06571aa81ec85ee3a781d7439816859b36338ade28f00c3608acb06c893deb2f
System.map     ffe8595e6f833d872d5b90ff8252789d39647456e8d3fb79925a3326bd68338d
Module.symvers c5c30705a62e06a5ca65c9404eac1decab8b5991186ce935fd32e5c60f13e7d9
```

Temporary boot and the final permanent boot both loaded all 25 vendor modules.
Audio, Wi-Fi with real traffic, two cameras, the accelerometer, Bluetooth,
compat vDSO, Binder caches, KCAL, BFQ availability, deadline default and the
KGSL vote passed. The nine Android profile values were present after a normal
boot, and the critical kernel-log scan was clean. The live boot-partition hash
matched `boot.img` exactly.

Two simultaneous 256 MiB workers completed 16 rounds each with no OOM, panic
or hung task. Curated evidence is in `benchmarks/results/r8-c8/`.

The most relevant five-versus-ten-run medians compare the c4/c5 baseline with
the final ThinLTO candidate:

| Metric | c8 change |
|---|---:|
| same-core idle p50 / p95 / p99 | -5.63% / -7.72% / -8.61% latency |
| same-core loaded p50 / p95 / p99 | -5.45% / -5.70% / -7.11% latency |
| cross-core loaded p50 / p95 / p99 | -4.91% / -5.79% / -19.70% latency |
| random-read IOPS / p95 | +4.90% / -9.55% latency |
| sequential read / write | +0.77% / +5.52% |
| random-write p99 | +117.89% latency regression |

The repeated wake-latency direction is strong enough to retain ThinLTO. The
eMMC tails are not: c8 contains no default scheduler switch, and the volatile
random-write regression remains explicit evidence rather than being attributed
to a specific patch.

## c2 to c3 measurements

The native harness used two repetitions per candidate. That is enough to catch
large regressions, not enough to turn small differences into universal claims.

| Native metric | c3 vs c2 median |
|---|---:|
| CPU, 1 thread | +0.03% |
| CPU, 4 threads | +0.43% |
| memory copy / read / write | +0.79% / +2.63% / +0.39% |
| loaded cross-core wake mean | -21.82% latency |
| loaded cross-core wake p95 | -3.14% latency |
| loaded cross-core wake p99 | -63.17% latency |
| sequential read / write | +0.38% / -4.19% |
| random read / write IOPS | -1.30% / -14.82% |

Idle and same-core wake tails were mixed, and the eMMC write results were
highly variable. c3 contains no block-I/O change, so the two-run random-write
drop is retained as regression evidence but is not attributed to the four c3
commits.

The existing UI runs show the complete production-stack result, not a pure
kernel-only A/B: the old c2 profile guard silently skipped r8, while the c3 run
used the corrected balanced profile and `sched_schedstats=0`.

| UI metric | c2 | c3 production | Change |
|---|---:|---:|---:|
| NewPipe median | 1,446 ms | 1,480 ms | +2.35% |
| NewPipe p90 | 1,995 ms | 1,742 ms | -12.68% |
| NewPipe mean | 1,562.2 ms | 1,529.2 ms | -2.11% |
| Cromite median | 805 ms | 792 ms | -1.61% |
| Cromite p90 | 853 ms | 795 ms | -6.80% |
| Cromite mean | 815.2 ms | 765.6 ms | -6.08% |
| Settings p50 / p90 | 11 / 13 ms | 10 / 13 ms | -9.1% / same |
| Settings p95 / p99 | 25 / 28 ms | 16 / 18 ms | -36.0% / -35.7% |
| Settings jank | 0.16% | 0.16% | same |

The longer r5 -> r8 performance history is summarized in
[PERFORMANCE_DYNAMICS.md](PERFORMANCE_DYNAMICS.md). There is deliberately no
single "overall gain" percentage: CPU throughput, storage, frame tails,
memory-pressure behavior and optional features are different dimensions.

## Evaluated but not shipped

- GPU overclocking was rejected for the live speed bin.
- Compile-time removal of scheduler statistics was rejected because of broad
  vendor-module CRC drift; the reversible runtime switch gives the useful
  part without changing the ABI.
- Config-only image trimming did not reduce the fixed boot payload enough to
  justify losing diagnostics.
- Scheduler donor changes with mixed measurements, wrong prerequisites or
  misleading commit labels were excluded instead of being accumulated for a
  larger feature count.
- A wholesale scheduler replacement and major CPU/GPU frequency-table changes
  remain excluded. ThinLTO moved from experiment to c8 only after the ordered
  repeat and full module/runtime qualification.

## Development roadmap

The next useful work is ordered by expected value, not by patch count:

1. **c9 soak and power evidence.** Several days of normal child-use, suspend/
   resume, Wi-Fi/video and unplugged battery measurements. This is deliberately
   the final wave before promoting c8-derived work to stable.
2. **Storage-latency investigation.** Reproduce the volatile random-write tail
   with more controlled cache/thermal state, then evaluate one compatible eMMC
   or block-layer change at a time. No change should ship merely to improve one
   benchmark run.
3. **Scheduler wave 2.** Review Android-common and compatible SDM439 EAS fixes
   for idle placement, load tracking and migration. Each patch stays separate
   and must improve the workload it actually targets.
4. **Low-memory wave 2.** Instrument reclaim/compaction, PSI and `lmkd` during
   real app switching, then consider narrow 4.9 backports that reduce refaults
   or stalls. A larger synthetic allocation alone is not the goal.
5. **Power/thermal policy.** Measure CPU idle residency, schedutil frequency
   time and thermal throttling before altering governor or bus/devfreq policy.
6. **Optional features.** WireGuard, additional filesystems or sound controls
   are possible only where they solve a real use case and do not destabilize
   the 2 GB production configuration.

This keeps development moving in larger, coherent waves while preserving an
independently testable rollback point after each one.

The detailed Ukrainian backlog, including c4-c8 candidate groups and rejected
ideas, is maintained in [KERNEL_ROADMAP.uk.md](KERNEL_ROADMAP.uk.md).

## Evidence limits

- One TB-X505L 2/32 GB unit, one Lenovo vendor build and one crDroid/PHH
  Android 13 system were exercised.
- Automated checks do not replace long-duration battery, suspend/resume and
  physical input-latency testing.
- The network smoke test proves availability, not superiority of a congestion
  algorithm on every connection.
- Linux 4.9 and the Android 10 vendor security level remain old.

## Donor and upstream references

- [Compatible SDM439 donor tree](https://github.com/mi-sdm439/android_kernel_xiaomi_sdm439)
- [Android common-kernel documentation](https://source.android.com/docs/core/architecture/kernel/android-common)
- [Linux FQ-CoDel documentation](https://www.kernel.org/doc/html/latest/networking/sch_fq_codel.html)
- [Google BBR source and documentation](https://github.com/google/bbr)
