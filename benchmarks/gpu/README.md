# GPU fragment benchmark

`tbx-gpu-bench.c` creates an off-screen EGL pbuffer and repeatedly executes a
64-iteration fragment shader. Every frame ends with `glFinish()`, so Adreno
cannot discard overwritten tile-buffer work. The tool reports elapsed time,
FPS, megapixels per second and a one-pixel checksum.

Build the AArch64 Android binary with:

```powershell
.\scripts\build-gpu-benchmark.ps1 -NdkRoot C:\path\to\android-ndk
```

Example on the tablet:

```text
adb push artifacts/tools/tbx-gpu-bench-aarch64 /data/local/tmp/tbx-gpu-bench
adb shell chmod 0755 /data/local/tmp/tbx-gpu-bench
adb shell /data/local/tmp/tbx-gpu-bench 768 768 600 5
```

This is intentionally a narrow fragment-ALU workload. It validates actual GPU
clock scaling and repeatability; it does not replace application, memory-bus,
thermal-soak or battery testing.
