# r8-c9 GPU/CPU qualification summary

The final `4.9.337-tbx505l-r8-c9-oc3645-cpu1305+ #28` image was tested first
with `fastboot boot` and then from the permanently written boot partition.

Verified live state:

```text
GPU levels     364500000 320000000 Hz
GPU measured   approximately 364498256-364503236 Hz under load
CPU levels     1305600 1497600 1708800 1958400 2016000 kHz
boot SHA-256   773611c66e7458529446c05aa974c25d4c4cef8a7d49329af40bd3ea1f75b4ce
modules        25
```

The five short GPU runs in `gpu-five-runs.csv` averaged 14.463 FPS versus the
verified 320 MHz baseline of 12.702 FPS (+13.86%). Long GPU and mixed CPU/GPU
tests remained stable; the mixed test peaked at 54 C. The complete release
evidence archive contains clock telemetry, regulator readback, the module ABI
audit and post-stress kernel-log scans.

See `docs/GPU_OVERCLOCK.md` for the clock-path investigation and rejected
candidates. These numbers describe one narrow fragment workload on one tablet,
not whole-system performance.
