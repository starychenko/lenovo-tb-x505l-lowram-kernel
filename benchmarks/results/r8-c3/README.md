# r8-c3 privacy-reviewed results

This directory preserves the project-authored evidence for the permanently
qualified `4.9.337-tbx505l-r8-fastpath-c3` candidate.

- `runtime-validation.txt` is the successful production-mode hardware,
  feature, runtime-profile and critical-log validation.
- `native-results.txt`, `identity.txt` and the telemetry CSV files contain two
  controlled CPU, memory, wake-latency and direct-I/O repetitions.
- `launch-summary.csv`, `jank-summary.csv` and `ui-production-identity.txt`
  contain five launches per application and two Settings scroll samples with
  the production profile active.
- `memory-pressure-result.txt` and `memory-pressure-telemetry.csv` cover two
  simultaneous 256 MiB workers over 16 rounds.

Full dmesg, raw `getprop`, screenshots, device identifiers and third-party APKs
are deliberately excluded. Interpretation and limitations are in
`docs/R8_ENGINEERING.md`.
