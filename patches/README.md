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
