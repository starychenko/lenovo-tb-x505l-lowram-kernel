# Measured performance dynamics from r5 to r8-c8

## Short answer

There is no honest single percentage for the whole tablet. The measured trend
is:

- raw CPU throughput is effectively unchanged;
- common browser/UI work is modestly faster or smoother, usually by a few
  percent, with some much larger reductions in slow frame/wake-up tails;
- the r6 storage/runtime work produced the clearest application-level gain;
- memory behavior and kernel maintainability improved more than headline
  benchmark scores;
- NewPipe and eMMC write results remain mixed.

## Development stages

| Stage | Main purpose | Measured result |
|---|---|---|
| r5 | Make the 2 GB Android stack internally consistent | PSI-backed `lmkd`, memory cgroups, LZ4 zRAM, KSM and no competing legacy LMK; stable 700 MiB pressure run |
| r6 | Deadline I/O plus measured Android policy | CPU within 0.3% of r5; random read IOPS +20.75%, random write IOPS +12.63%; balanced PCMark Storage mean +6.3% vs r5 mean |
| r7 | Linux 4.9.205 -> 4.9.337 and vendor/camera compatibility | Mostly a maintenance/stability release; vs the 4.9.227 control, memory copy +10.04% and read +4.45%, UI and eMMC mixed |
| r8-c2 | Binder/vDSO/network/KCAL feature pack | New useful paths verified; no general speed claim |
| r8-c3 | Scheduler/reclaim/compaction/I2C fast paths plus corrected production profile | Cross-core loaded mean -21.82% and p99 -63.17% vs c2 in two native runs; Cromite mean -6.08% and Settings p95/p99 about -36% in the production UI run |
| r8-c8 | Scheduler/KGSL, ARM64/mremap, optional BFQ and A53 ThinLTO | vs c4/c5 baseline: typical same-core wake latency -5.5% to -8.6%, cross-core p50/p95/p99 -4.9%/-5.8%/-19.7%; eMMC tails remain mixed |

## c8 targeted compiler result

The final comparison uses five c4/c5 baseline samples and ten ThinLTO samples
split around a return to baseline. This reduces, but does not eliminate,
thermal and order bias.

| Metric | c8 vs c4/c5 |
|---|---:|
| same-core idle p50 / p95 / p99 | -5.63% / -7.72% / -8.61% latency |
| same-core loaded p50 / p95 / p99 | -5.45% / -5.70% / -7.11% latency |
| cross-core loaded p50 / p95 / p99 | -4.91% / -5.79% / -19.70% latency |
| sequential read / write | +0.77% / +5.52% |
| random-read IOPS | +4.90% |
| random-write p99 | +117.89% latency regression |

The repeated wake-latency result justified retaining ThinLTO. Storage is too
volatile to claim a general gain, and `deadline` remains the default.

## r6: the clearest controlled system gain

The three-run native comparison kept CPU throughput essentially flat while
deadline improved direct random I/O:

| Metric | r6-c2 vs r5 median |
|---|---:|
| random-read IOPS | +20.75% |
| random-read p50 / p95 / p99 latency | -11.37% / -11.11% / -28.38% |
| random-write IOPS | +12.63% |
| random-write p50 / p95 / p99 latency | -3.91% / -16.24% / -28.70% |
| memory copy / read / write | +4.56% / +4.11% / -0.33% |

With the balanced Android profile, warm PCMark Work rose from 5,252 to 5,349
(+1.8%). PCMark Storage averaged 4,849 versus 4,563 for r5 (+6.3%). In the
two-run SQLite means, read/update/insert/delete improved by approximately
3.8%/11.2%/17.9%/26.8%.

The cost proxy was about +5.6% CPU cycles and +9.8% context switches during the
same UI workload, with -8.1% CPU migrations. Average temperature rose 0.22 C
and the observed peak rose 1 C. That is not an unplugged battery-life result.

## r7: newer base, not a universal speed release

Against the usable 4.9.227 control, Linux 4.9.337 changed the native medians as
follows:

| Metric | r7 change |
|---|---:|
| CPU, 1 / 4 threads | -0.01% / +0.09% |
| memory copy / read / write | +10.04% / +4.45% / +0.27% |
| sequential read / write | +1.25% / -6.29% |
| random read / write IOPS | -3.29% / -8.11% |

NewPipe and Cromite launch medians were effectively unchanged; Settings jank
was mixed. The value of r7 is the 4.9.337 base, repaired vendor ABI, camera PM
QoS fix and clean permanent qualification.

## c3 production UI and long-range trend

The c3 production run is compared with the old r5 UI evidence below. These are
not a same-day A/B, so treat them as direction, not laboratory precision.

| UI metric | r5 | r8-c3 | Trend |
|---|---:|---:|---:|
| NewPipe median | 1,507 ms | 1,480 ms | -1.79% |
| NewPipe mean | 1,509.9 ms | 1,529.2 ms | +1.28% |
| NewPipe p90 | 1,534 ms | 1,742 ms | +13.56% |
| Cromite median | 818 ms | 792 ms | -3.18% |
| Cromite mean | 820.4 ms | 765.6 ms | -6.68% |
| Cromite p90 | 836 ms | 795 ms | -4.90% |
| Settings jank | 0.16% | 0.16% | same |
| Settings p50 / p90 | 12 / 13 ms | 10 / 13 ms | -16.7% / same |
| Settings p95 / p99 | 17 / 18 ms | 16 / 18 ms | -5.9% / same |

The useful practical conclusion is not "the tablet is X% faster". Browser and
typical frame latency improved modestly, loaded wake-up tails improved strongly
in the short c2/c3 native comparison, and CPU throughput stayed flat. NewPipe
tail latency and random writes still need attention.

## What improved without a benchmark percentage

- Android now has the PSI/memcg interfaces its `lmkd` expects.
- The legacy kernel LMK no longer races userspace `lmkd`.
- 32-bit vendor/app clock calls can use a compat vDSO.
- Binder hot allocations use dedicated caches.
- Camera lifecycle, vendor-module ABI and permanent boot are verified.
- A 512 MiB c3 pressure run and the complete production hardware validator
  finished without OOM, panic, hung task or critical kernel log.

Those changes reduce architectural debt and failure risk even when an app
launch stopwatch does not move.

## Measurement limits

- Results come from one tablet and old eMMC whose cache, wear and background
  state create substantial variance.
- r5/r6 and r7 controls are strong within their own test cycles; r5-to-c3 is a
  historical trend, not one interleaved experiment.
- The c2 UI run used ROM defaults because the old profile guard skipped r8;
  c3 used the corrected production profile. It measures the shipped stack, not
  four kernel commits in isolation.
- Two c2/c3 native repetitions can expose large changes but are weak evidence
  for small percentages.
