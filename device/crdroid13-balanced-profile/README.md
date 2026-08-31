# crDroid 13 balanced runtime profile

This companion profile is for the tested TB-X505L configuration only:

- Lenovo TB-X505L 2/32 GB;
- stock Lenovo Android 10 vendor `X505L_S001149_221018_ROW`;
- crDroid 9.10 Android 13 PHH GSI;
- a qualified kernel whose release contains `tbx505l-r6`, `tbx505l-r7` or
  `tbx505l-r8-*`.

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
scheduler statistics          0
```

The script refuses another Lenovo model and refuses a kernel without a
qualified r6/r7/r8 identity. Every write is read back and verified. The final
setting disables continuous scheduler-statistics accounting after Android's
`atrace.rc` enables it during boot. Tracing tools can still enable it again
when required; the profile reapplies the production value on the next boot.

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

The hook starts before PHH's unrelated 30-second cleanup delay. It waits only
until every policy node is writable, applies the profile once, then applies it
again five seconds after `sys.boot_completed`. The second pass is required
because Android init or PowerHAL can rewrite scheduler and governor policy
during service startup. The installer removes the previous log; wait for
`stage=post-boot` before evaluating the final readback.

If r5 or another kernel is running, the profile logs a skip and changes
nothing. The installer migrates the original r6-only hook marker in place so
existing installations do not acquire a duplicate boot hook.

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

The r7 release retained the same scheduler nodes and the installer/readback
path, including an automatic post-reboot apply, was verified after the
permanent r7 flash. The performance percentages above remain r6 measurements;
no separate r7 PCMark gain is claimed.

On r8-c2, a controlled live A/B check found that disabling scheduler statistics
reduced cross-core wake-up mean latency by roughly 7-9% and loaded p95 by about
2%, without a measurable single-thread throughput loss. The r8 profile keeps
the kernel ABI unchanged and applies that reversible runtime policy instead of
compiling out `SCHEDSTATS`/`SCHED_INFO`.

The same nine production values were read back by the full validator after the
permanent r8-c8 boot and again from the final permanently flashed r8-c9 boot.
The r8 identity guard accepts c9 and the post-boot log reported
`profile=balanced-ui status=applied`. This confirms application of the profile;
it is not a new PCMark or battery-life measurement.
