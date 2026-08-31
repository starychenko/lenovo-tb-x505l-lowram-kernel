# Встановлення та відкат

## Перед початком

- Тільки Lenovo TB-X505L 2/32 ГБ.
- Перевірений vendor: `TB-X505L_S001149_221018_ROW`.
- Bootloader має бути розблокований.
- Потрібні робочі `adb`, `fastboot`, нормальний USB-кабель і заряд понад 50%.
- Обов'язково збережіть власний boot-розділ.

## Перевірка завантаженого файла

```powershell
Get-FileHash -Algorithm SHA256 .\tb-x505l-lowram-r7-boot.img
```

Очікуваний SHA-256:

```text
4c30c952703b5d509953a06c4a66cfee60f08395f06555e2e5027623b9846cc3
```

Розмір: 67 108 864 байти.

## Backup власного boot

Якщо ROM дозволяє root ADB:

```text
adb root
adb shell "dd if=/dev/block/by-name/boot of=/data/local/tmp/boot-backup.img bs=1048576"
adb pull /data/local/tmp/boot-backup.img ./boot-backup.img
adb shell "rm -f /data/local/tmp/boot-backup.img"
```

Збережіть SHA-256 і ще одну копію на іншому диску. Заводський boot у публічному релізі не розповсюджується.

## Спочатку тільки тимчасовий запуск

```text
adb reboot bootloader
fastboot boot tb-x505l-lowram-r7-boot.img
```

Ця команда нічого не записує. Перевірте тач, жести, Wi-Fi, звук, обидві камери, мікрофон, заряджання та sleep/wake.

Очікувана діагностика:

```text
adb root
adb shell uname -a
adb shell "cat /proc/modules | wc -l"
adb shell cat /proc/asound/cards
adb shell cat /sys/block/zram0/comp_algorithm
adb shell cat /sys/kernel/mm/ksm/run
```

Має бути `4.9.337-tbx505l-r7-4.9.337-compat-vendor+ #14`, 25 модулів, аудіокарта
`sdm439-snd-card-mtp`, `[lz4]`, KSM `1` і `[deadline]` у
`/sys/block/mmcblk0/queue/scheduler`.

## Постійна прошивка

Тільки якщо тимчасовий запуск пройшов повну перевірку:

```text
adb reboot bootloader
fastboot flash boot tb-x505l-lowram-r7-boot.img
fastboot reboot
```

Після завантаження звірте записаний розділ:

```text
adb root
adb shell "dd if=/dev/block/by-name/boot bs=1048576 2>/dev/null | sha256sum"
```

Результат має починатись із `4c30c952` і повністю збігатись із SHA-256
завантаженого r7-образу.

## Додатковий профіль швидкодії Android 13

Перевірений профіль EAS/schedutil не зашитий у boot-образ. Він призначений лише
для тієї ж crDroid 9.10 Android 13 PHH GSI. Увімкніть root ADB у PHH settings і
виконайте:

```powershell
.\device\crdroid13-balanced-profile\install.ps1 `
  -Adb C:\path\to\adb.exe `
  -Serial DEVICE_SERIAL
```

Після перезавантаження дочекайтесь
`profile=balanced-ui status=applied` у
`/data/local/tmp/tb-x505l-balanced-profile.log` (асинхронний hook може
працювати до двох хвилин). Видалення не потребує прошивки ядра:

```powershell
.\device\crdroid13-balanced-profile\uninstall.ps1 `
  -Adb C:\path\to\adb.exe `
  -Serial DEVICE_SERIAL
```

Після видалення перезавантажте планшет, щоб повернути штатні runtime-значення.

## Відкат

```text
adb reboot bootloader
fastboot flash boot boot-backup.img
fastboot reboot
```

На тестовому планшеті не працює Volume Up, тому основний безпечний шлях до bootloader - `adb reboot bootloader`. Якщо Android не запускається, використовуйте офіційний Lenovo rescue/software-fix з прошивкою саме для вашої моделі.
