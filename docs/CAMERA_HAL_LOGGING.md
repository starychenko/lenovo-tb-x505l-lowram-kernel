# Camera HAL logging on the Android 13 GSI

The tested tablet combines the Lenovo Android 10 vendor partition
`X505L_S001149_221018_ROW` with an Android 13 GSI. Both cameras work, but the
old Qualcomm camera stack labels many normal or unsupported-feature paths as
`ERROR` and can write hundreds of lines during one camera session.

This note separates a real kernel defect from vendor logging noise. They must
not be treated as the same problem.

## Real kernel defect

The camera driver used an atomic guard when adding its PM QoS request, removed
the request on shutdown, but did not reset the guard. A later camera-provider
lifecycle therefore skipped `pm_qos_add_request()` and tried to update an
inactive object. The visible result was:

```text
pm_qos_update_request() called for unknown object
WARNING:
Call trace:
```

The released r7 source resets the guard exactly once when removing the request.
The 4.9.337 c4 image was then exercised with both camera IDs and three complete
Camera2 process restarts. The result was zero unknown-object messages, zero
kernel warnings and zero call traces. The same c4 boot image was subsequently
flashed permanently. This is a functional kernel correction, not log
filtering.

## Why the remaining messages are not missing vendor files

The complete factory package is available locally as
`TB_X505L_USR_S001149_2210181723_Q00015_ROW`. A SHA-256 comparison covered 415
camera-related files from its `vendor.img`: the provider, HAL, camera XML,
chromatix, sensor, actuator and EEPROM libraries. Every file on the tablet was
byte-for-byte identical to the factory image; there were no missing or changed
files.

The live camera metadata reports `flash.info.available = FALSE` for both
cameras. The common Qualcomm pipeline nevertheless visits LED/flash paths and
prints messages such as:

```text
Calibrate data size 0 not expected with tuning size: 0
func_tbl for submodule 4 is NULL
CAM_INTF_META_FLASH_POWER failed
```

That zero-length calibration is for the absent flash, not evidence that the
camera EEPROM was erased. The rear HI556 EEPROM is read successfully and
returns autofocus values including macro 390 and infinity 241. Lenovo's EEPROM
plugin prints those valid numbers with Android error priority as well.

The high-rate metadata line is another old HAL logging choice:

```text
replace sensorExpTime (33333333)
```

`33333333` ns is one 30 fps frame. The HAL is reporting its metadata fallback,
not a camera crash.

## Quiet profile

Qualcomm's own camera logging implementation exposes persistent per-module log
levels. The project uses those controls instead of modifying proprietary
libraries. The quiet profile keeps the global diagnostic level enabled and
sets only the repeatedly noisy sensor, interface, ISP, stats, image, HAL and
MCI modules to level 0.

Apply it from Windows with root ADB available:

```powershell
.\scripts\configure-camera-hal-logging.ps1 `
  -AdbPath "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" `
  -Mode quiet `
  -Serial DEVICE_SERIAL
```

Restore useful Qualcomm error/warning diagnostics before investigating a new
camera problem:

```powershell
.\scripts\configure-camera-hal-logging.ps1 `
  -AdbPath "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" `
  -Mode diagnostic `
  -Serial DEVICE_SERIAL
```

The script verifies every property, restarts only the camera provider and
`cameraserver`, then confirms that camera IDs 0 and 1 are still enumerated.
The values are persistent across reboots.

## Validation and limits

With the final targeted profile, both cameras opened, switched and reopened.
All of the following high-volume patterns were absent:

- LED calibration size zero;
- missing flash submodule and flash-power metadata;
- chromatix/HVX and linearization messages;
- missing AF mixer, invalid stats port and unused depth-map messages;
- repeated `replace sensorExpTime` metadata messages.

The kernel log remained free of Camera PM QoS warnings and call traces. A few
low-rate messages remain deliberately visible: valid Lenovo AF values printed
as errors, and buffer/close diagnostics around a camera switch. Removing the
former would require patching the proprietary EEPROM blob only to change log
priority; hiding the latter would make real camera troubleshooting worse.

The quiet profile reduces log noise and logd work. It does not replace the
factory tuning, add flash hardware or repair a genuinely broken camera. Use the
diagnostic profile before collecting logs for any future functional defect.
