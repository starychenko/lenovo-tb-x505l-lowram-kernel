# Development analysis tools

These scripts preserve the ABI/source-comparison work used before the final r5
design. They require Linux tools such as `modinfo`, `modprobe`, `nm`, `git` and
GNU coreutils.

The scripts intentionally accept paths as arguments. They do not contain a
tablet serial number, a local workstation path or proprietary module binaries.
Use extracted modules only on a machine where you are authorized to inspect
them; do not attach those binaries to public issues.
