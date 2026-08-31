# TB-X505L GPU clock investigation

## Final result

The r8-c9 release raises the tested Adreno 504 GPU level from 320 MHz to an
exact measured 364.5 MHz and raises the lowest exposed CPU level from 960 MHz
to 1305.6 MHz. The CPU maximum remains the qualified 2016 MHz level.

This is device-specific work for the tested TB-X505L speed-bin 10 unit. A
frequency present in a shared SDM439 source table is not proof that another
parent clock, fuse bin or tablet can produce it.

## Clock path

The qualified path uses the 19.2 MHz reference oscillator and GPLL3:

```text
19.2 MHz * (37 + 31/32) = 729 MHz
729 MHz / 2 = 364.5 MHz GPU clock
```

Qualcomm's source describes GPLL3 as dedicated to Oxili and forces the
software post-divider to two to match the fused hardware behavior:

https://android.googlesource.com/kernel/msm/+/ca33a5cfe805d24ef139fafc93e65e6b74219f45%5E2..ca33a5cfe805d24ef139fafc93e65e6b74219f45/

The compatible SDM439 table contains nominal GPLL3 entries above 355.2 MHz,
but those requested values were never assumed to be real until measured on
the live branch clock:

https://github.com/LineageOS/android_kernel_samsung_sdm429/blob/lineage-22.2/drivers/clk/msm/clock-gcc-8952.c

On this tablet, a live sweep kept the integer part at 37 while varying the
fractional part. With the fixed divide-by-two path, the observed route tops out
just below 364.8 MHz. The release uses 364.5 MHz to stay 0.3 MHz below that
boundary.

## Candidate results

| Candidate | Requested | Measured behavior | Fragment benchmark | Decision |
|---|---:|---:|---:|---|
| stock/c8 | 320 MHz | 320 MHz | 12.702 FPS | baseline |
| GPLL0-labelled | 400 MHz | remained near 320 MHz | no useful gain | rejected |
| GPLL3 probe | 400 MHz | about 361.6 MHz | 14.322 FPS | proof only |
| GPLL6 AUX | 432 MHz | about 308.6 MHz | 12.235 FPS | rejected |
| dedicated GPLL6 graphics | 432 MHz | Adreno clock stuck off; Android did not complete boot | unavailable | rejected |
| final GPLL3 | 364.5 MHz | 364.498-364.503 MHz | 14.463 FPS five-run mean | qualified |

The final five short runs ranged from 14.459 to 14.468 FPS, a 13.86% mean
increase over the 320 MHz baseline. A 600-frame run produced 14.458 FPS. A
second 600-frame run completed concurrently with a 45-second four-thread CPU
load at 14.496 FPS; all 45 telemetry samples held 364.5 MHz and the highest
sampled temperature was 54 C.

The benchmark is deliberately narrow. It proves real fragment-ALU scaling and
repeatability, not a universal 13.86% improvement in every application.

## Voltage and bus votes

The GCC fmax table maps the relevant ranges to Qualcomm RPM corner IDs:

```text
up to 320 MHz -> 128
up to 400 MHz -> 192
up to 510 MHz -> 256
up to 560 MHz -> 320
up to 650 MHz -> 384
```

These values are corner identifiers, not literal millivolts. The 364.5 MHz
entry requests the LOW/192 corner. During the live GPU load the shared
`gcc-vdd_dig` aggregate remained at 256 because another GCC consumer held a
higher vote, so the GPU path was not undervolted. The final level reuses the
donor 400 MHz bus votes `bus-freq=5`, `bus-min=4`, `bus-max=7`.

## Final artifact identity

```text
source commit  0ea8dc3e34140ac48640f23dacf8b9a04fd2b26e
source tree    88f8929f885b45ec856f746a0a3f350efc1d40de
config         174a1ef87b42f87576ca62420533fffb3aff18afcd96844074c55443cd7588e6
Image          7970d89029da7761bd1280fbb75f9b8ecf7b6aa233d94bd1837579f7890f17fd
kernel_dtb     7992d0c4c960bd959dcfb8fa2638834cb00c2e9111e279beb527fa4befe78661
boot.img       773611c66e7458529446c05aa974c25d4c4cef8a7d49329af40bd3ea1f75b4ce
```

The boot image first completed temporary boot, repeated GPU testing and mixed
CPU/GPU stress. It was then flashed permanently; the live boot-partition
readback exactly matched the released boot image. Twenty-five Lenovo vendor
modules loaded, audio and Wi-Fi were present, and the post-stress/post-flash
kernel scans contained no GPU fault, Adreno reset, stuck clock, watchdog,
Oops, BUG or Call trace attributable to the candidate.

## DTB handling

The release uses the exact concatenated `kernel_dtb` extracted from a matching
TB-X505L boot image and patches only the verified SDM429 MTP entry. The helper
`scripts/patch-oc-kernel-dtb.py` checks model, compatibility, CPU table,
speed-bin and existing power levels before writing anything. Its safe default
is 364.5 MHz; rejected frequencies require `--allow-experimental`.

Users must provide their own matching boot image. The project does not publish
Lenovo's factory boot image or proprietary vendor modules.
