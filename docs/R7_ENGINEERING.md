# r7 engineering: Linux 4.9.337 integration

## Scope

r7 updates the qualified TB-X505L kernel line from Linux 4.9.205 to 4.9.337
while retaining the Lenovo device support, low-RAM policy and exact stock
audio/WLAN module set used by r5/r6. It is not a generic Qualcomm image and it
does not update the Android 10 vendor partition.

The final source state is:

```text
branch  r7-upstream-4.9.337-merge
commit  ca9f99dcda9bc0cf55271157d3a5718ed8cf6e3b
config  ddb6b6277eedc4f0c45c55a2196d1fb5ffb1fe15409e86a4568124d099845fac
```

The final c4 image was first qualified with `fastboot boot`, then written to the
boot partition. The partition readback matched the release image SHA-256
exactly.

## Source integration path

The upgrade was deliberately staged instead of replacing the vendor tree in a
single unreviewed step:

| Commit | Purpose |
|---|---|
| `7ec91bbe06f9` | Import the exact staged Lenovo source on the original CAF 4.9.205 base |
| `d763cb2a74e4` | Apply the previously qualified TB-X505L low-RAM and module-policy changes |
| `b53e7515dd04` | Merge CAF `LA.UM.8.6.2.r1-06600`, producing the 4.9.206 development base |
| `114b84d0d6f1` | Merge CAF `LA.UM.8.6.2.r1-09500`, producing the 4.9.227 development base |
| `1338960fbff7`..`5374d09e558c` | Revert three incompatible KGSL/cfg80211 assumptions for the shipping firmware/modules |
| `6892bc998017` | Merge the device line into KudProject's Linux 4.9.337 baseline `cad7430de036` |
| `2383da7c2f10` | Adapt A6xx postamble handling to the legacy shared scratch layout |
| `33c271fee2fd` | Restore the Lenovo timer helper ABI required by `pronto_wlan.ko` |
| `ca9f99dcda9b` | Fix the Qualcomm camera PM QoS request lifecycle |

The complete source archive attached to v1.2.0 is authoritative. The short
camera patch in `patches/` is useful for review, but it is not a substitute for
the complete merged source tree.

## Candidate progression

- 4.9.206 c1 established that the first CAF update could boot, load the vendor
  modules and survive the low-memory workload.
- 4.9.227 candidates separated newer kernel behavior from Adreno firmware and
  vendor-module compatibility. The `compat-vendor-c2` build became the
  controlled comparison baseline.
- The first 4.9.337 ABI audit found one real regression: the Lenovo WLAN module
  required `__fsl_a008585_read_cntvct_el0`, which the merged tree no longer
  exported. c3 restored that helper and had zero missing kernel symbols.
- c3 exposed a repeatable camera-close warning in `pm_qos_update_request()`.
  c4 resets the request-state atomic when the QoS request is removed. Repeated
  rear/front camera lifecycles then completed without that warning or a call
  trace.

Intermediate images are engineering evidence, not alternative releases. Only
the c4 identity below is supported by v1.2.0.

## Final build identity

```text
Linux localhost 4.9.337-tbx505l-r7-4.9.337-compat-vendor+ #14 SMP PREEMPT
Mon Aug 31 10:45:00 UTC 2026 aarch64
```

```text
boot.img       4c30c952703b5d509953a06c4a66cfee60f08395f06555e2e5027623b9846cc3
Image          2ddcf2b84d3b4e5588d3ab43c7ac4835c0249c57e2a6e01d0ec665d074ba6de1
config         ddb6b6277eedc4f0c45c55a2196d1fb5ffb1fe15409e86a4568124d099845fac
System.map     2cc922803e61f6eeb526736ac8a1cd206ea0811eb9dd19aef8cec1892ccddc5f
Module.symvers 5844ecfc61a6dee4ec2ec2b91659a0625528b0c883fd3f6c0dfdfb5ca8226a0d
compile.h      583d658492b8002f356d5921cd170883a440ab1e28fca018bb41431d596c081d
```

The 67,108,864-byte boot image preserves the qualified Lenovo boot header,
command line, empty Android ramdisk and DTB. The extracted DTB SHA-256 is
`e95ed19a66da21c63f5943e50fba34e023cf227882ebb9360747a8dc716e59e7`,
identical to the source boot image used for repacking.

## Vendor-module ABI audit

All 25 shipping Lenovo audio/WLAN modules were checked against the final
`Module.symvers`:

```text
requirement rows      2004
unique symbols         980
stable unique CRCs     223
unique CRC drift       432
module dependencies    325
missing kernel symbols   0
```

The existing 25-name compatibility allowlist remains necessary because 432
unique symbol CRCs differ from the known-good kernel. It does not globally
disable `CONFIG_MODVERSIONS` for unrelated modules. Signature enforcement is
still permissive because Lenovo's private signing key is unavailable; this
security trade-off is unchanged from r5/r6.

Reproduce the audit on Linux/WSL with a directory containing the exact 25
vendor modules:

```bash
scripts/check-vendor-module-crcs.sh \
  /path/to/vendor-modules \
  /path/to/known-good/Module.symvers \
  /path/to/r7/Module.symvers \
  > module-crc-comparison.tsv \
  2> module-crc-summary.txt
```

The script distinguishes missing kernel symbols from dependencies exported by
another vendor module. It does not redistribute the `.ko` inputs.

## Physical validation

The final c4 image was validated on one TB-X505L 2/32 GB with crDroid 9.10
Android 13 PHH GSI and Lenovo vendor `X505L_S001149_221018_ROW`.

Verified after temporary boot and/or the byte-identical permanent flash:

- Android completed boot and the written boot partition matched
  `4c30c952...46cc3`;
- all 25 vendor modules loaded;
- Wi-Fi associated and completed a real Internet ping;
- Bluetooth reached `ON`;
- the `sdm439-snd-card-mtp` audio card, touch/pen input and navigation worked;
- both camera IDs, rear/front previews and repeated open/close cycles worked;
- the camera, Wi-Fi, Bluetooth, sound, touch, microphone and accelerometer were
  also physically checked during qualification;
- `deadline`, 1 GiB LZ4 zRAM, PSI, KSM and userspace `lmkd` remained active;
- the first permanent-boot dmesg scan contained no kernel panic, BUG, Oops,
  WARNING or call trace.

The tested tablet's microphone remains weak on every kernel and is likely a
mechanical issue.

## Controlled performance results

The same native benchmark binary and test controls were used for three runs of
4.9.227 c2 and three runs of 4.9.337 c3. c4 changes only the built-in camera QoS
lifecycle and has the same external module ABI as c3.

Selected median changes from 4.9.227 to 4.9.337:

| Metric | Change |
|---|---:|
| CPU, 1 thread | -0.01% |
| CPU, 4 threads | +0.09% |
| memory copy | +10.04% |
| memory read | +4.45% |
| memory write | +0.27% |
| sequential read | +1.25% |
| sequential write | -6.29% |
| random-read IOPS | -3.29% |
| random-write IOPS | -8.11% |

The eMMC results had materially higher run-to-run variance than CPU results and
do not justify a general storage-performance claim. r7 is primarily an
upstream-integration and maintainability release, not a universal speed boost.

Android UI controls were also effectively mixed: NewPipe median launch was
1,511 ms versus 1,515 ms, Cromite was 811 ms versus 809 ms, while the Settings
jank median was 0.32% versus 0.16%. These differences are published to avoid
selective reporting.

## Memory-pressure result

Two simultaneous 350 MiB workers completed 30 memory rounds each. At the
heaviest sampled point:

```text
minimum MemAvailable   18,636 KiB
minimum SwapFree      433,812 KiB
maximum PSI some avg10  59.31
maximum PSI full avg10  15.25
```

There was no process or kernel crash. At roughly 18 MiB available RAM,
`GraphicsStats-d` recorded two order-0 `GFP_ATOMIC` allocation failures. This
is evidence of the intentionally extreme workload, not proof that 2 GB can
absorb arbitrary pressure without latency or allocation failures.

The device-side wrapper refuses arbitrary output paths and refuses to reuse an
existing directory:

```text
adb push tbxbench /data/local/tmp/tbxbench
adb push scripts/memory-pressure.sh /data/local/tmp/memory-pressure.sh
adb shell chmod 0755 /data/local/tmp/tbxbench /data/local/tmp/memory-pressure.sh
adb shell /data/local/tmp/memory-pressure.sh \
  /data/local/tmp/tbxbench 350 30 2 \
  /data/local/tmp/tbx-memory-pressure-r7
adb pull /data/local/tmp/tbx-memory-pressure-r7 ./r7-memory-pressure
```

This workload intentionally drives a 2 GB tablet close to exhaustion. Keep a
known-good boot backup and do not run it while unsaved user work is open.

## Camera findings

The c3 warning was a kernel lifecycle bug, not evidence that Lenovo's camera
files had been mixed with another firmware. A comparison of 415 camera-related
HAL, provider, XML, sensor, actuator, EEPROM and chromatix files found all 415
identical between the live vendor partition and the archived S001149 factory
vendor image.

After the c4 fix and the documented quiet logging profile:

- the stale PM QoS object warning and kernel call trace were absent;
- both camera IDs opened repeatedly;
- common misleading calibration/flash/chromatix log spam was suppressed;
- six valid AF calibration values are still logged at error priority by the
  proprietary HAL;
- one Camera2 application-level `camera driver error` occurred during a switch,
  although both devices continued to work.

The logging profile changes verbosity properties only. It does not replace or
patch proprietary camera blobs. See [CAMERA_HAL_LOGGING.md](CAMERA_HAL_LOGGING.md).

## Balanced Android profile

The optional crDroid 13 profile is still separate from `boot.img`. Its device
guard now accepts qualified r6 and r7 kernels, migrates the old r6-only marker
without duplicating the boot hook, and verifies every written scheduler node.
Installation and readback were verified on the permanently flashed r7 kernel.
The published PCMark percentages remain measurements from r6; no new r7
PCMark gain is claimed.

## Limits

- Only one TB-X505L 2/32 GB unit and one vendor/GSI combination were tested.
- TB-X505F, TB-X505X and other vendor builds are not qualified.
- Linux 4.9 is end-of-life and the Android 10 vendor security level remains
  old. A higher patch number does not make this a current security platform.
- The source tree deliberately carries compatibility reverts and a narrow
  vendor-module CRC exception. It is unsuitable as a generic 4.9.337 base.
- Battery life was not measured unplugged over multiple days.
- Keep a verified device-specific boot backup and test future images with
  `fastboot boot` before writing the boot partition.

## Published evidence boundary

The v1.2.0 evidence archive contains candidate identities, raw benchmark
results, comparison CSV files, ABI reports, pressure telemetry and final
camera/permanent-flash summaries. Full `getprop`, raw boot dmesg/logcat and UI
captures were excluded because they contain device serial/PSN data or are not
needed to reproduce the published conclusions. No result was removed merely
because it was a regression.
