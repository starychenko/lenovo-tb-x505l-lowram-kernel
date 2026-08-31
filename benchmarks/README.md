# TB-X505L r6 benchmark suite

The r6 evaluation does not use one aggregate benchmark as proof. It separates
the subsystems changed by each experiment and records workload-specific
regressions as well as gains.

Privacy-reviewed generated summaries are published in `results/`. Full local
screenshots and logs are not required to reproduce the project-authored tests
and are not committed.

## Native benchmark

`native/tbxbench.c` is a dependency-free AArch64 executable built statically by
`scripts/build-native-benchmark.sh`. `scripts/benchmark-native.ps1` runs it on
the tablet under controlled starting conditions and captures telemetry with
`scripts/benchmark-monitor.sh`.

Covered workloads:

- single-thread and four-thread integer CPU throughput;
- 64 MiB memory copy, read and write throughput;
- same-core and cross-core pipe wake-up latency at idle and under load;
- direct synchronous sequential and random file I/O, including p50, p95 and
  p99 latency rather than throughput alone.

The wrapper disables Wi-Fi and the display for the native run, waits for two
consecutive temperature samples at or below 40 C, restores device state in a
`finally` block, and captures the kernel log after the suite.

## Android UI benchmark

`scripts/benchmark-ui.ps1` measures repeated cold app launches and a
deterministic bidirectional Settings scroll. It resets and reads Android
`gfxinfo`, so the result includes rendered frame counts, jank percentage and
frame-time percentiles rather than only an app launch timestamp.

`scripts/benchmark-ui-counters.sh` adds system-wide `simpleperf` counters and
thermal/frequency telemetry. Those counters are a cost proxy: they can show
that a responsiveness profile executes more CPU work, but they are not a
substitute for an unplugged battery-life test.

## PCMark

PCMark Work 3.1 remains useful because it drives complete Android application
paths. Storage 2.1 covers app-private storage, shared storage and SQLite.
Neither score identifies scheduler latency, memory bandwidth or the power cost
of a tuning change, so PCMark is used alongside the native and UI suites.

## Comparison rules

- Compare identical ROM, vendor, apps and battery/thermal conditions.
- Use a temporary `fastboot boot` candidate before flashing it.
- Run at least three short deterministic tests; run long app benchmarks at
  least twice when practical.
- Compare medians for noisy latency and launch data.
- Keep a small gain when it repeats and has no larger regression; do not reject
  it solely because it is small.
- Do not add unrelated improvements together as if they were measured in one
  combined run.
- Scan `dmesg` for BUG, Oops, call trace, hung task, OOM and I/O errors after
  each candidate.
