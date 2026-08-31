# Published r6 result data

These are the privacy-reviewed summaries used by `docs/R6_ENGINEERING.md`.

- `native-controlled-summary.csv` contains three controlled repetitions for
  r5, r6-c1 and r6-c2. Decimal commas are preserved from the Windows locale;
  every field is quoted.
- `ui/` contains the generated launch and jank summaries for the baseline,
  EAS-only, schedutil-only and combined profile experiments.
- `pcmark-work.csv` and `pcmark-storage.csv` transcribe the locally captured
  PCMark result screens. Empty component cells mean that only the aggregate
  score was retained for that run.
- `runtime-profile-cost.csv` is an explicitly approximate summary of the
  system-wide counter/thermal proxy. It is not a battery-energy measurement.

Raw local captures also contain screenshots, full telemetry and kernel logs.
They are intentionally excluded from Git because logs can expose device-local
identifiers and the PCMark APK is third-party copyrighted software. The source
and wrappers required to reproduce the project-authored tests are published.

`r8-c2/` contains the privacy-reviewed runtime, native, UI and 512 MiB pressure
smoke evidence for the temporary-booted r8 feature pack. It is regression
evidence only; it is not presented as a matched r7/r8 performance comparison.

`r8-c3/` contains the c3 native, production UI, pressure and permanent-runtime
validation summaries. `r8-c2-vs-c3-summary.csv` is the two-repetition native
comparison. Small deltas and the variable eMMC results are not treated as
conclusive; see `docs/R8_ENGINEERING.md` and `docs/PERFORMANCE_DYNAMICS.md`.

`r8-c8/` contains the final production validator, the 512 MiB pressure run,
five c4/c5 baseline samples, five A53 samples and two five-run ThinLTO sets.
`targeted-summary.csv` combines all ten ThinLTO samples and keeps the volatile
eMMC tail regression visible. See `docs/R8_ENGINEERING.md` for the acceptance
decision and evidence limits.
