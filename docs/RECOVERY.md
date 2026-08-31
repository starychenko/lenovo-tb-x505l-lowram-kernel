# Recovery paths

## Android still boots

Use ADB to avoid relying on the faulty Volume Up key:

```text
adb reboot bootloader
fastboot devices
fastboot flash boot boot-backup.img
fastboot reboot
```

The backup must come from the same tablet/firmware and should be checksum-verified first.

## Stuck at boot animation but ADB appears

Do not immediately wipe data. Check:

```text
adb devices
adb shell getprop sys.boot_completed
adb shell getprop init.svc.bootanim
adb shell uname -a
```

If ADB is usable, reboot to bootloader and restore boot. A slow first start is different from a kernel crash; the qualified GSI may spend around a minute at its animation.

## Fastboot is available directly

```text
fastboot devices
fastboot getvar product
fastboot getvar unlocked
fastboot flash boot boot-backup.img
fastboot reboot
```

Confirm the detected device before any write.

## Neither Android nor fastboot is reachable

Use Lenovo's official rescue/software-fix tooling and the exact TB-X505L regional firmware. This repository intentionally does not mirror proprietary factory packages.

A factory rescue can replace more partitions and may erase user data. Use it only after boot-only recovery paths are exhausted and verify the selected model/build in the Lenovo tool.

## After rollback

Verify:

```text
adb shell uname -a
adb shell getprop sys.boot_completed
```

If the original behavior returns with the original boot image, collect sanitized logs from the custom kernel and open an issue.
