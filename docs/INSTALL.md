# Installation and rollback

## Preconditions

- Exact model: Lenovo TB-X505L, 2/32 GB.
- Tested vendor: `TB-X505L_S001149_221018_ROW`.
- Unlocked bootloader.
- Working `adb` and `fastboot` connection.
- Battery comfortably above 50% and a stable USB cable.
- A personal backup of the current boot partition.

Do not treat a similar product name as proof of compatibility. Check the model, vendor fingerprint and boot-image size.

## Download and verify

Download these files from the same GitHub Release:

- `tb-x505l-lowram-r5-boot.img`
- `SHA256SUMS.txt`

On PowerShell:

```powershell
Get-FileHash -Algorithm SHA256 .\tb-x505l-lowram-r5-boot.img
```

Expected r5 boot hash:

```text
3dabe282b5f82efa5d4e7496835aca8731d6d1ed3975e281adedeba2fdb3b61f
```

The image is exactly 67,108,864 bytes.

## Back up your own boot partition

The project does not distribute Lenovo's factory boot image. If the running ROM permits root ADB:

```text
adb root
adb shell "dd if=/dev/block/by-name/boot of=/data/local/tmp/boot-backup.img bs=1048576"
adb pull /data/local/tmp/boot-backup.img ./boot-backup.img
adb shell "rm -f /data/local/tmp/boot-backup.img"
```

Record its checksum and keep a second copy off the tablet:

```powershell
Get-FileHash -Algorithm SHA256 .\boot-backup.img
```

If `adb root` is unavailable, obtain the exact factory firmware from Lenovo or boot a trusted recovery that can read the partition. Do not use another person's boot image unless the device and firmware are proven identical.

## Temporary boot: mandatory first step

```text
adb reboot bootloader
fastboot devices
fastboot boot tb-x505l-lowram-r5-boot.img
```

`fastboot boot` loads the image into memory without writing the boot partition. Wait for Android to complete startup, then verify:

- touch and navigation gestures;
- Wi-Fi association and internet access;
- speakers and media playback;
- front and rear cameras;
- microphone recording;
- charging and USB;
- sleep/wake and screen rotation.

Useful checks with root ADB:

```text
adb root
adb shell uname -a
adb shell cat /proc/asound/cards
adb shell ip -brief address show wlan0
adb shell cat /proc/pressure/memory
adb shell cat /sys/block/zram0/comp_algorithm
adb shell cat /sys/kernel/mm/ksm/run
adb shell "cat /proc/modules | wc -l"
```

Expected essentials are kernel build `#5`, 25 loaded modules, audio card `sdm439-snd-card-mtp`, active `wlan0`, `[lz4]`, and KSM value `1`.

## Permanent installation

Only after the temporary image passes the complete hardware checklist:

```text
adb reboot bootloader
fastboot devices
fastboot flash boot tb-x505l-lowram-r5-boot.img
fastboot reboot
```

After Android boots, verify the written partition:

```text
adb root
adb shell "dd if=/dev/block/by-name/boot bs=1048576 2>/dev/null | sha256sum"
```

It must print the release hash `3dabe282...3b61f`.

## Rollback

Use the backup from your own device:

```text
adb reboot bootloader
fastboot flash boot boot-backup.img
fastboot reboot
```

Verify its SHA-256 before flashing.

## Broken Volume Up button

The qualification tablet has a sticking/non-working Volume Up button. The preferred recovery route is therefore:

```text
adb reboot bootloader
```

If Android cannot provide ADB, use a known-working hardware path for the exact tablet or Lenovo's official rescue/software-fix tooling with the correct firmware. See [RECOVERY.md](RECOVERY.md).
