# Reversible LineageOS 18.1 tuning

These scripts preserve the user-space tuning pass used before kernel work. They
target the same TB-X505L/S001149/PHH GSI stack, require ADB root, and deliberately
avoid a hard-coded workstation path or device serial.

`apply-tuning.ps1` first verifies the exact known PHH boot-hook SHA-256, then
disables only optional completed-setup, telemetry, printing,
screensaver, live-wallpaper, NFC and Jelly packages for user 0; sets animation
scales to 0.5; enables automatic time; applies the device boot hook; compiles
installed Cromite/NewPipe packages when present; and runs `fstrim`.

`restore-tuning.ps1` re-enables the package list, restores animation scales and
removes only this project's exact boot-hook block. Both scripts refuse an
unknown hook instead of overwriting it. Read the scripts before use. The final tested tablet
later used gesture navigation successfully, so navigation-mode selection is not
forced by these preserved scripts.
