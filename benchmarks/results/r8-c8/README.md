# r8-c8 privacy-reviewed results

This directory preserves the project-authored evidence for the permanently
qualified `4.9.337-tbx505l-r8-c8-thinlto` candidate.

- `runtime-validation.txt` is the successful production-mode hardware,
  feature, profile and critical-log validation after permanent flashing.
- `targeted-c4c5-baseline-5x.txt` is the five-run pre-compiler baseline.
- `targeted-c8-a53-5x.txt` is the five-run A53/inlining candidate.
- `targeted-c8-thinlto-5x-a.txt` and `-b.txt` are two five-run ThinLTO sets;
  the second set ran after returning to the baseline to reduce order bias.
- `targeted-summary.csv` uses the five baseline samples and all ten ThinLTO
  samples. Lower latency is better; higher IOPS and MiB/s are better.
- `memory-pressure-result.txt` and `memory-pressure-telemetry.csv` cover two
  simultaneous 256 MiB workers over 16 rounds.

The eMMC tail-latency samples are volatile. The random-write p99 regression is
published rather than hidden, but c8 does not switch away from the qualified
`deadline` default. Full dmesg, raw properties, device identifiers and
third-party binaries are deliberately excluded.
