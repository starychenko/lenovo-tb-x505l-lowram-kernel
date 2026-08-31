# r8-c2 privacy-reviewed smoke results

These files preserve the project-authored r8-c2 regression evidence without
publishing raw `getprop`, full dmesg, device identifiers or third-party APKs.

- `runtime-validation.txt` is the successful active feature-pack validation.
- `native-results.txt` contains two short CPU, RAM, wake-up-latency and I/O
  repetitions; `identity.txt` preserves their controls.
- `launch-summary.csv` and `jank-summary.csv` are the Android UI smoke
  summaries. `ui-identity.txt` records that the old profile guard skipped r8,
  so this UI run used ROM-default scheduler policy.
- `memory-pressure-result.txt` and `memory-pressure-telemetry.csv` describe the
  concurrent 512 MiB pressure run.

The exact test controls and evidence limits are documented in
`docs/R8_ENGINEERING.md`. Scripts and native benchmark source are public, so
the run can be repeated without relying on a proprietary benchmark APK.
