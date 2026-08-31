# Rejected GPU-clock candidates

These configs preserve the local-version identities used while investigating
360, 400 and 432 MHz candidates. GPU frequency is controlled by source and DTB,
not by a Kconfig option, so these files are not standalone overclock profiles
and must not be treated as flashable releases.

- 400 MHz through GPLL0 changed the software label but the measured hardware
  clock remained near 320 MHz.
- 400 MHz through GPLL3 measured about 361.6 MHz and proved that real scaling
  was possible, but it was not an exact 400 MHz clock.
- 432 MHz through GPLL6 AUX measured about 308.6 MHz and regressed performance.
- The dedicated GPLL6 graphics path booted the kernel but Adreno failed to
  initialize, so Android did not complete boot.

The final r8-c9 release uses the separately qualified 364.5 MHz GPLL3 entry.
See `docs/GPU_OVERCLOCK.md` for the measurements and limits.
