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
- `tb-x505l-r7-base-caf06600.config` is the first booted CAF 4.9.206 update.
- `tb-x505l-r7-upstream-caf09500.config` is the unqualified CAF 4.9.227 base.
- `tb-x505l-r7-upstream-caf09500-compat-old-adreno-fw.config` and
  `tb-x505l-r7-upstream-caf09500-compat-vendor.config` preserve the two
  compatibility paths tested at 4.9.227; the vendor-compatible build became
  the controlled r7 comparison baseline.
- `tb-x505l-r7-upstream-4.9.337-compat-vendor.config` is the exact final
  v1.2.0 config. Its SHA-256 is
  `ddb6b6277eedc4f0c45c55a2196d1fb5ffb1fe15409e86a4568124d099845fac`.
  See `docs/R7_ENGINEERING.md`.

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

Do not merge fragments into an arbitrary Qualcomm 4.9 config and assume ABI
compatibility. The final r7 config is tied to the complete 4.9.337 source at
commit `ca9f99dcda9bc0cf55271157d3a5718ed8cf6e3b`; use them together.
