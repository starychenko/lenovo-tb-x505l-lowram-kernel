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
- `tb-x505l-r8-fastpath-c3.config` is the permanently qualified c3 config.
  Its functional options are identical to c2; only `CONFIG_LOCALVERSION`
  changes because c3's scheduler, reclaim, compaction and I2C work is in the
  source patch. Its SHA-256 is
  `a7b9cb80d60cca83306e897647c49571033427c9ced57b36858a6b62ea996005`.
- `tb-x505l-r8-c4c5.config` is the scheduler/KGSL plus ARM64/mremap candidate
  input config. SHA-256:
  `71f886f5e36ead426f010353d8093acfc2afffb2fb2c4929be4bf8331c98d788`.
- `tb-x505l-r8-c6-bfq.config` adds BFQ v8r10 as selectable while retaining
  `deadline` as default. SHA-256:
  `01d479cc54bfea4cb095ddfd9dd1bed37a83fe453bae8347e4d3a9d072344dd8`.
- `tb-x505l-r8-c7-power.config` is the SDM429 KGSL power-vote candidate.
  SHA-256:
  `0d4f4efbc911a48227bc97140a8abe823a1070d69674b3756b1649526a5143dc`.
- `tb-x505l-r8-c8-a53.config` is the normalized A53/inlining control config.
  SHA-256:
  `0f24871274adf110d2de63935de89621f1556e64ee6694824ae9b9a4f384c2b6`.
- `tb-x505l-r8-c8-thinlto.config` is the exact permanently qualified c8
  ThinLTO config. SHA-256:
  `06571aa81ec85ee3a781d7439816859b36338ade28f00c3608acb06c893deb2f`.
- `tb-x505l-r8-c9-oc3645-cpu1305.config` is the exact final v1.4.0 config.
  It retains c8 ThinLTO and changes the local-version identity for the source
  and DTB changes that raise the CPU floor to 1305.6 MHz and add the qualified
  364.5 MHz GPU level. SHA-256:
  `174a1ef87b42f87576ca62420533fffb3aff18afcd96844074c55443cd7588e6`.

The rejected 360/400/432 local-version configs are preserved under
`historical/gpu-oc-candidates/`. Frequency policy is implemented by source and
DTB, not Kconfig, so those files are engineering identities rather than
standalone overclock profiles.

Low-RAM base delta retained by every later candidate:

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
r8-c2 is tied to `476936bf...`; c3 is tied to `45a98eac...`; c8 is tied to
`40a804803797...`; final c9 is tied to `0ea8dc3e3414...`. Reconstruct c9 from
the exact r7 base by applying the c2 patch, the c3 incremental patch, the
ordered `patches/r8-c4-c8/` series and then `patches/r8-c9/`.
