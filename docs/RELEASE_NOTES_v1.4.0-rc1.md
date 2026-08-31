# v1.4.0-rc1 - r8 c4-c8 ThinLTO candidate

This pre-release advances the tested TB-X505L kernel from r8-c3 to the
permanently qualified `4.9.337-tbx505l-r8-c8-thinlto` candidate.

It adds focused scheduler and KGSL submission changes, optimized ARM64
`memcmp`/`strlen`, a large-mapping `mremap` fast path, BFQ v8r10 as an optional
I/O scheduler, relaxed SDM429 GPU CPU-latency votes and an A53-targeted ThinLTO
build. `deadline` remains the storage default. No CPU/GPU overclock, fsync
disable or unvalidated frequency table is included.

The final image still uses Android Clang 9.0.8. ThinLTO is linked with system
GNU gold 1.16 instead of the older bundled gold 1.12. The image is about
1.2 MiB larger inside boot, but two ordered test sets retained a 5-9% reduction
in typical same-core kernel wake latency and roughly 5-20% in cross-core
percentiles. Storage results remain noisy; the random-write p99 regression is
published and is not claimed as an improvement.

The candidate passed temporary boot, ten ThinLTO repetitions, the complete
25-module CRC audit, a concurrent 512 MiB memory-pressure run and the full
production validator. It was then flashed on the test tablet; the boot
partition readback exactly matched the released image:

```text
b0186ee9d2968051af7224802f8c040332f7672324779f3c91c7f31534d555bf
```

The release remains limited to one TB-X505L 2/32 GB unit with Lenovo vendor
`TB-X505L_S001149_221018_ROW` and crDroid 9.10 PHH GSI. Test with
`fastboot boot`, retain a boot backup and do not flash this image on X505F,
X505X or another vendor build.
