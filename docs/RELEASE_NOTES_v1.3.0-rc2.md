# v1.3.0-rc2 - r8 fast-path candidate c3

This pre-release keeps every r8-c2 feature and adds four focused source
changes for the Lenovo TB-X505L 2/32 GB:

- conditional scheduler sync-wake affinity;
- bounded high-order reclaim when compaction can satisfy the allocation;
- unevictable-page compaction disabled by default;
- Qualcomm I2C block mode for small transfers used by the Goodix touch path.

The crDroid/PHH companion profile now accepts r8, restores
`sched_schedstats=0`, runs before PHH's unrelated cleanup delay and reapplies
after Android completes boot.

c3 completed temporary boot, a concurrent 512 MiB pressure run, native and UI
tests, the full production hardware/feature validator and a cold boot. It was
then permanently flashed on the tested tablet. The boot-partition readback
matched the released image SHA-256 exactly, all 25 Lenovo modules loaded and
the final critical kernel-log scan was clean.

Raw CPU throughput remains essentially unchanged. The two-run c2/c3 native
comparison improved loaded cross-core mean and p99 wake latency by 21.82% and
63.17%, while idle latency and eMMC writes were mixed. The production UI run
improved Cromite mean launch by 6.08% and Settings p95/p99 frame times by about
36%; NewPipe results were mixed. These results and their limitations are
published in `docs/R8_ENGINEERING.md` and `docs/PERFORMANCE_DYNAMICS.md`.

No GPU overclock is included. This is still physically tested on one tablet,
so use `fastboot boot` before flashing another device and retain an exact boot
backup. Do not use it on TB-X505F, TB-X505X or an unmatched vendor build.
