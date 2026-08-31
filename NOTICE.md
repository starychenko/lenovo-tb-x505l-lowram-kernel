# Notices and provenance

This repository documents and packages a device-specific Linux kernel build for Lenovo TB-X505L.

## Upstream sources

- Linux/Qualcomm kernel source: GPL-2.0-only.
- Lenovo device changes: derived from the publicly available TB-X505 kernel work and the source state identified in [docs/SOURCE_PROVENANCE.md](docs/SOURCE_PROVENANCE.md).
- Linux 4.9.337 integration base: KudProject `kernel_msm-4.9` commit
  `cad7430de0364a908d73cea93d06f9ca44ad439e`, also GPL-2.0-only.
- PHH GSI integration: minimal patches target exact files from pinned
  `device_phh_treble` commit
  `41f0817f3fab4361216c5e3bce3660c5045f665b`. That upstream repository does
  not declare a repository license, so its complete shell files are referenced
  rather than duplicated here.
- MagiskBoot is referenced as an external repacking tool and is not redistributed.

## Files intentionally not distributed

- the device's factory boot image;
- IMEI, serial number, Android identifiers or account data;
- proprietary Lenovo vendor modules and firmware;
- Magisk binaries;
- private device backups;
- obsolete experimental boot images.

The final boot image contains the GPL kernel and the device tree required to boot this model. It contains no ramdisk and no user data.

Lenovo, Android, Qualcomm, LineageOS, PHH and Magisk are names of their respective owners. This is an independent community project and is not endorsed by Lenovo or those projects.
