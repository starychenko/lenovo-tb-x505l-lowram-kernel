# Device-side integration

`phh-on-boot-page-cluster.patch` is the exact, review-friendly delta applied to
the tested GSI. Its base is PHH `device_phh_treble` commit
`41f0817f3fab4361216c5e3bce3660c5045f665b`, `phh-on-boot.sh` Git blob
`d2d5b0a5611d97341886cc52a3ec13426c2d2326`:

```text
https://github.com/phhusson/device_phh_treble/blob/41f0817f3fab4361216c5e3bce3660c5045f665b/phh-on-boot.sh
```

The upstream repository does not declare a repository license, so this project
does not duplicate the complete before/after file. The reversible tuning
scripts instead verify the known original or modified SHA-256 and transform the
live file using only the small block stored in this project.

The kernel image itself does not force `vm.page-cluster=0`. The tested PHH GSI applies that value from `phh-on-boot.sh`, guarded by the Lenovo TB-X505L vendor fingerprint.

Apply the patch only to the matching `phh-on-boot.sh`; do not replace a full
script with a copy from another GSI release.

On the qualified tablet the system partition is presented through an overlay whose writable layer is under `/cache/overlay/system/upper`. Overlay layouts vary between PHH builds; inspect the live mount instead of assuming that path.

Verification:

```text
adb root
adb shell cat /proc/sys/vm/page-cluster
```

Expected value: `0`.

## Android 13 balanced profile

`crdroid13-balanced-profile/` contains the measured, reversible EAS/schedutil
companion profile for the tested crDroid 9.10 PHH GSI. It stays outside the
kernel because these values are Android runtime policy and may be replaced by
PowerHAL or init after the kernel boots.
