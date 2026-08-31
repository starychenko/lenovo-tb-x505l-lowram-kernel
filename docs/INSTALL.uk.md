# Встановлення та відкат

## Перед початком

- Тільки Lenovo TB-X505L 2/32 ГБ.
- Перевірений vendor: `TB-X505L_S001149_221018_ROW`.
- Bootloader має бути розблокований.
- Потрібні робочі `adb`, `fastboot`, нормальний USB-кабель і заряд понад 50%.
- Обов'язково збережіть власний boot-розділ.

## Перевірка завантаженого файла

```powershell
Get-FileHash -Algorithm SHA256 .\tb-x505l-lowram-r5-boot.img
```

Очікуваний SHA-256:

```text
3dabe282b5f82efa5d4e7496835aca8731d6d1ed3975e281adedeba2fdb3b61f
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
fastboot boot tb-x505l-lowram-r5-boot.img
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

Має бути kernel `#5`, 25 модулів, аудіокарта `sdm439-snd-card-mtp`, `[lz4]` і KSM `1`.

## Постійна прошивка

Тільки якщо тимчасовий запуск пройшов повну перевірку:

```text
adb reboot bootloader
fastboot flash boot tb-x505l-lowram-r5-boot.img
fastboot reboot
```

Після завантаження звірте записаний розділ:

```text
adb root
adb shell "dd if=/dev/block/by-name/boot bs=1048576 2>/dev/null | sha256sum"
```

## Відкат

```text
adb reboot bootloader
fastboot flash boot boot-backup.img
fastboot reboot
```

На тестовому планшеті не працює Volume Up, тому основний безпечний шлях до bootloader - `adb reboot bootloader`. Якщо Android не запускається, використовуйте офіційний Lenovo rescue/software-fix з прошивкою саме для вашої моделі.
