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
- `tb-x505l-r8-feature-pack-c2.config` is the temporary-booted r8-c2 config.
  It adds Binder/vDSO32 source support, BBR, Westwood, FQ, FQ-CoDel and KCAL
  while retaining r7's 100 Hz, deadline and vendor-module compatibility base.
  Its SHA-256 is
  `d0d68d6d28e3733840d55a452d76654b6b007cbb46793c35369015278e70cf90`.
  See `docs/R8_ENGINEERING.md`.

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
compatibility. The final r7 config is tied to source commit `ca9f99dc...`; the
r8-c2 config is tied to `476936bf...` or the exact r7 base plus the published
r8 patch.
