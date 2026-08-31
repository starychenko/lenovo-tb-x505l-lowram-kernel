# Kernel configurations

- `tb-x505l-baseline.config` is the reconstructed stock-compatible baseline used for comparison.
- `tb-x505l-lowram-r5.config` is the exact final build config.
- `tb-x505l-r6-c1.config` is the experimental 300 Hz + CFQ candidate. It is
  preserved as negative engineering evidence and is not recommended.
- `tb-x505l-r6-c2.config` keeps 100 Hz and selects deadline as the default I/O
  scheduler. It is the qualified candidate that produced the benchmark data.
- `tb-x505l-lowram-r6.config` is the release-identity copy of r6-c2. Its only
  additional difference is `CONFIG_LOCALVERSION="-tbx505l-r6"`; see
  `docs/R6_ENGINEERING.md`.

Important delta:

```text
CONFIG_PSI=y
CONFIG_MEMCG=y
CONFIG_MEMCG_SWAP=y
CONFIG_MEMCG_SWAP_ENABLED=y
CONFIG_KSM=y
CONFIG_ANDROID_LOW_MEMORY_KILLER=n
CONFIG_CRYPTO_LZ4=y
CONFIG_LZ4_COMPRESS=y
CONFIG_LZ4_DECOMPRESS=y
```

Do not merge fragments into an arbitrary Qualcomm 4.9 config and assume ABI compatibility. Use the complete final config with the corresponding source release.
