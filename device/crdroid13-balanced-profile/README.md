# crDroid 13 balanced runtime profile

This companion profile is for the tested TB-X505L configuration only:

- Lenovo TB-X505L 2/32 GB;
- stock Lenovo Android 10 vendor `X505L_S001149_221018_ROW`;
- crDroid 9.10 Android 13 PHH GSI;
- a kernel whose release contains `tbx505l-r6`.

It is deliberately separate from the kernel. EAS task placement and
`schedutil` response thresholds are Android runtime policy, and Android's
PowerHAL or init scripts can replace values that are compiled into a kernel.
Keeping the profile separate also makes it possible to remove the policy
without reflashing `boot.img`.

## Tested values

```text
top-app boost               10
top-app prefer_idle          1
foreground boost             5
foreground prefer_idle       1
schedutil hispeed_freq 1497600
schedutil hispeed_load       75
schedutil up_rate_limit_us    0
schedutil down_rate_limit_us 20000
```

The script refuses another Lenovo model and refuses a kernel without an r6
identity. Every write is read back and verified.

## Install

Enable rooted ADB in the PHH settings, connect the tablet, and run from
PowerShell:

```powershell
.\device\crdroid13-balanced-profile\install.ps1 `
  -Adb C:\path\to\platform-tools\adb.exe `
  -Serial DEVICE_SERIAL
```

The installer:

1. verifies the exact vendor fingerprint and root ADB;
2. remounts the PHH system overlay;
3. saves the current `phh-on-boot.sh` under the ignored `backups/` directory;
4. installs an idempotent marked hook and the profile script;
5. verifies the marker count and the pushed script SHA-256.

After reboot:

```powershell
adb shell cat /data/local/tmp/tb-x505l-balanced-profile.log
adb shell /system/bin/tb-x505l-balanced-profile.sh show
```

If r5 or another kernel is running, the profile logs a skip and changes
nothing.

## Remove

```powershell
.\device\crdroid13-balanced-profile\uninstall.ps1 `
  -Adb C:\path\to\platform-tools\adb.exe `
  -Serial DEVICE_SERIAL
```

The uninstaller removes only the marked profile block and its script. It does
not replace the whole PHH boot hook, so unrelated local changes are preserved.
Reboot after removal; the kernel and ROM then recreate their default runtime
values.

## Measured trade-off

On the tested unit, two warm PCMark Storage 2.1 runs averaged 4,849 with the
profile, compared with 4,543 on the same r6-c2 kernel without it (+6.7%). A
warm PCMark Work 3.1 run improved from 5,252 to 5,349 (+1.8%). Repeated Settings
scrolls reduced typical frame latency while leaving p99 unchanged.

This is not free performance. A system-wide `simpleperf` proxy during the same
UI workload recorded about 5.6% more CPU cycles and 9-10% more context
switches. USB power made current measurements unsuitable for a battery-life
claim. Treat the profile as a responsiveness setting and re-check real standby
and active-use battery life over several days.
