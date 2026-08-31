# r6 engineering evaluation

This document records the r6 experiments performed on one Lenovo TB-X505L
2/32 GB tablet with the stock `X505L_S001149_221018_ROW` vendor and crDroid
9.10 Android 13 PHH GSI. r5 remained the persistent fallback during candidate
testing; r6 images were initially started with `fastboot boot`.

## Candidates

| Build | Kernel timer | Default I/O scheduler | Purpose |
|---|---:|---|---|
| r5 | 100 Hz | CFQ | persistent known-good baseline |
| r6-c1 | 300 Hz | CFQ | test whether finer scheduler ticks improve interaction latency |
| r6-c2 | 100 Hz | deadline | isolate the I/O scheduler from the timer change |

All candidates use the r5 source/ABI compatibility work and load the same 25
Lenovo audio/WLAN modules. Wi-Fi, audio, both cameras, Bluetooth, touch and the
accelerometer were physically checked on r6-c2.

## What the custom tests found

CPU throughput was effectively unchanged. Against r5 medians, r6-c1 was 0.3%
slower in the one-thread test and 0.7% slower with four threads; r6-c2 was
within 0.3% of r5. That is expected: neither candidate changes CPU frequency
tables or instruction execution.

The 300 Hz candidate did not improve this device. Its cross-core idle wake-up
p99 was 62.6% worse in the controlled native suite, its Settings scroll tail
rose from 17/18 ms at p95/p99 to 25/27 ms, and app launches were slightly
slower. r6-c1 is therefore retained as engineering evidence, not as a release
candidate.

r6-c2 kept r5-like UI behavior and improved the direct random-I/O medians:

| Direct I/O metric | r6-c2 vs r5 median |
|---|---:|
| random read p50 | -11.4% latency |
| random read p95 | -11.1% latency |
| random read p99 | -28.4% latency |
| random read IOPS | +20.8% |
| random write p50 | -3.9% latency |
| random write p95 | -16.2% latency |
| random write p99 | -28.7% latency |
| random write IOPS | +12.6% |

The IOPS samples were noisy, and r6-c1 also improved several random-I/O tails,
so not every percentage can be attributed to deadline alone. The important
result is narrower: r6-c2 did not regress UI or CPU tests, and the targeted I/O
latency direction repeated.

## PCMark without the runtime profile

| Build | Work 3.1 warm | Storage 2.1 runs | Storage mean |
|---|---:|---:|---:|
| r5 | 5,242 | 4,509 / 4,617 | 4,563 |
| r6-c1, CFQ | 5,254 | 4,185 / 4,168 | 4,177 |
| r6-c1, runtime deadline | not used for selection | 4,282 / 4,444 | 4,363 |
| r6-c2, deadline | 5,252 | 4,644 / 4,442 | 4,543 |

The r6-c2 Storage aggregate is effectively tied with r5 because SQLite run
variation offsets its file-I/O result. This is why the kernel was not selected
from PCMark alone.

## Balanced Android runtime profile

Four EAS and `schedutil` variants were tested independently before combining
them. The retained profile uses modest top-app/foreground boosts and a higher
`schedutil` response threshold; the exact values and reversible installer are
in `device/crdroid13-balanced-profile/`.

Twenty launch repetitions and three Settings scroll repetitions produced:

| Metric | r6-c2 baseline | r6-c2 balanced |
|---|---:|---:|
| NewPipe launch median | 1,502 ms | 1,520 ms |
| Cromite launch median | 822 ms | 815 ms |
| Settings jank median | 0.32% | 0.16% |
| Settings p50 / p90 | 12 / 14 ms | 10 / 13 ms |
| Settings p95 / p99 | 17 / 18 ms | 18 / 18 ms |

The result is a trade: typical frame latency and Cromite improve, NewPipe is
about 1.2% slower, and worst-case p99 is unchanged.

A second warm PCMark Work run with the unchanged profile scored 5,349 versus
5,252 without it (+1.8%). Web browsing improved 5.7%, video 1.1%, photo 1.5%
and data manipulation 1.3%; writing was 0.2% lower.

Two Storage runs with the profile scored 4,906 and 4,791, averaging 4,849:

- +6.7% versus r6-c2 without the profile;
- +6.3% versus the r5 mean;
- internal file reads/writes generally improved about 1-2%;
- SQLite read improved 3.8%, update 11.2%, insert 17.9% and delete 26.8% using
  the two-run means.

The external sequential results did not improve, which is another reason not
to describe the profile as universally faster.

## Cost and decision

During the same repeated Settings workload, system-wide `simpleperf` recorded
about 5.6% more CPU cycles and 9-10% more context switches with the balanced
profile. Average thermal telemetry rose only about 0.2 C and the observed peak
rose from 42 C to 43 C. USB power was connected, so current readings cannot
support a battery-life conclusion.

The engineering decision is incremental rather than categorical:

- reject 300 Hz for this hardware because its regressions repeated;
- retain 100 Hz plus deadline as the r6 kernel direction;
- retain the balanced runtime policy as an optional, reversible companion
  because its UI, Work and Storage gains repeat;
- evaluate real unplugged battery life over several days before making that
  runtime policy the unconditional default for every user.

## Evidence limits

The percentages describe one physical unit and this exact ROM/vendor stack.
Flash wear, filesystem cache state and Android background work add variance,
especially to SQLite. The tests demonstrate behavior of these candidates; they
do not prove that a different TB-X505 variant, ROM, vendor image or battery
condition will respond identically.

## Final r6 qualification

The release-identity build keeps the r6-c2 code and configuration, changing
only the local version from the candidate name to `tbx505l-r6`.

```text
Linux release   4.9.205-tbx505l-r6+
build number    7
build timestamp Mon Aug 31 11:45:00 UTC 2026

config          055df656f6cbfaf33afa7c61153e537b96d3772181e078ff52c7501b21969353
Image           974d7ce683b25252743901f618cbb1024a66080ee684ba507dcbac657329f886
System.map      0d35d8c0ca2f435799f9fdd515df7293b79b9fd8bd788637ec44be7839b3ecda
Module.symvers  7c74085e951663ba6185e7576a59f62f3faa0157d86d0001aac494d428e2614e
boot.img        9e9bba24ab8af0ca19fc655ded6339a1fd1cfe3f944364aa61a0be2d917b8a72
stock DTB       e95ed19a66da21c63f5943e50fba34e023cf227882ebb9360747a8dc716e59e7
```

MagiskBoot re-opened the final boot image and reproduced the raw `Image` and
stock-DTB hashes above. The boot image was first started with `fastboot boot`.
After Android completed, the same image was flashed permanently. A direct
SHA-256 read of `/dev/block/by-name/boot` matched the local final image exactly.
Immediately before the flash, a new readback of the persistent r5 boot matched
its published hash
`3dabe282b5f82efa5d4e7496835aca8731d6d1ed3975e281adedeba2fdb3b61f`.

Post-flash checks covered 25/25 modules, audio card and audioserver, connected
Wi-Fi, two camera devices, active accelerometer, Goodix touch input and a real
Bluetooth OFF -> ON -> OFF cycle. The final native smoke covered CPU, RAM,
wake-up latency and direct I/O; a UI smoke covered app launches and a 621-frame
Settings scroll. No BUG, Oops, call trace, hung task, OOM, unknown symbol,
module-version mismatch or I/O error was found after the tests.

The profile hook was also removed with the published uninstaller, verified
absent, reinstalled, verified to have exactly one marker, and checked by
SHA-256. A real reboot had already shown that it applies all eight values after
the PHH boot hook finishes.
