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
