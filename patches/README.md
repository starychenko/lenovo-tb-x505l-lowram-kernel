# Source patch

`tb-x505l-lowram-r5.patch` is the exact five-file diff used by the final build. It contains:

1. Clang warning-option compatibility.
2. Python 3 conversion of the legacy compiler wrapper.
3. LZ4 as zRAM's compiled default when available.
4. Compound-head handling in the proc reclaim path.
5. Permissive module signing and the exact TB-X505L vendor-module CRC allowlist.

Validation performed before publication:

- reverse `git apply --check` against the modified build tree;
- forward apply against a fresh extraction of the frozen base archive;
- SHA-256 comparison of all five resulting files with the built source tree.

## r7 engineering patch

`4.9.337-camera-pm-qos-lifecycle.patch` is the camera PM QoS lifecycle fix
qualified on the final 4.9.337 c4 build. It is kept separate from the r5/r6
patch because r7 uses a different merged source base. The complete r7 source
state is published with v1.2.0; this small patch exists for focused review.

The c4 validation opened both camera IDs and repeated complete Camera2
lifecycles. The previous unknown-object warning and its call trace were absent.
See `docs/CAMERA_HAL_LOGGING.md` for the distinction between this kernel defect
and the unrelated proprietary Camera HAL log noise.

## r8 feature-pack patch

`tb-x505l-r8-feature-pack-c2.patch` is the consolidated source delta from the
exact r7 commit `ca9f99dcda9bc0cf55271157d3a5718ed8cf6e3b` to r8-c2 commit
`476936bf688`. It includes Binder caches, the compat-vDSO32 series, KCAL and
the two small build/style follow-ups. Networking algorithms were already
present in the source and are enabled by the c2 config.

The patch was checked forward in a detached worktree at the r7 base and in
reverse against the r8-c2 tree. SHA-256:

```text
b543bd902b5a72308f3300dc762827fad40710c2ab04f32558f36d6f0fa4bb4a
```

## r8 c3 fast-path patch

`tb-x505l-r8-fastpath-c3.patch` is the small incremental delta from c2 commit
`476936bf688557fb6edbe87ef7f0c4acc91592c6` to c3 commit
`45a98eac292f8b1fbf6f8e5b1130805691327e68`. It changes four files with 32
insertions and three deletions:

1. keep synchronous wake affinity only when the CPU is about to idle;
2. avoid excessive high-order reclaim when compaction is suitable;
3. default unevictable-page compaction to off;
4. use Qualcomm I2C block mode for small transfers.

It was checked forward against c2 and in reverse against c3. SHA-256:

```text
93d3de2d1dd607b18d03259235c9ca67f4d21f1f8d9e63a4cb34bd9726be15ef
```

## r8 c4-c8 patch series

`r8-c4-c8/` contains 17 ordered mail patches from c3 commit `45a98eac292f`
to c8 commit `40a804803797`. The series preserves the individual review and
rollback boundaries instead of publishing another opaque full-tree diff.
Applying it in a temporary Git index produced the exact c8 tree
`bff54dc04e870882f0cac4c5b953d73553c30681`. See the directory README and
`SHA256SUMS` for the complete manifest.

## r8 c9 CPU/GPU patch

`r8-c9/` contains the single incremental mail patch from c8 commit
`40a804803797` to final c9 commit `0ea8dc3e3414`. It raises the SDM429 CPU
floor from 960 to 1305.6 MHz, adds the qualified 364.5 MHz speed-bin 10 GPU
level and adds the corresponding fractional GPLL3 entry. Applying it to c8 in
a temporary Git index reproduced c9 tree
`88f8929f885b45ec856f746a0a3f350efc1d40de` exactly.
