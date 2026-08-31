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
