# Contributing

Contributions are welcome when they preserve the project's evidence-first safety model.

## Before opening a kernel change

1. State the exact device variant, RAM/storage configuration, vendor build and ROM/GSI.
2. Explain the measured problem, not only the proposed tweak.
3. Keep a working personal boot backup.
4. Build from the complete corresponding source and exact config.
5. Test with `fastboot boot` before any permanent flash.
6. Collect both positive functionality checks and negative kernel-log checks.

## Pull requests

- Keep each change narrowly scoped and explain its runtime contract.
- Include config deltas and toolchain identity.
- Do not commit generated output, proprietary modules, factory firmware, Magisk binaries or user data.
- Update documentation and the validation matrix when behavior changes.
- Do not weaken a security boundary without documenting the exact scope and consequence.
- Avoid benchmark-only CPU/GPU/thermal tweaks without repeatable latency, battery and stability evidence.

## Bug reports

Remove serial numbers, IMEI, MAC addresses, IP addresses, account names and tokens from logs. Include the rollback result so maintainers can distinguish a kernel regression from a ROM/vendor or mechanical problem.
