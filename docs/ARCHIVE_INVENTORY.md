# Preservation and publication inventory

This project is preserved as more than a single flashable image. The public
release is designed to remain useful even if an upstream branch or prebuilt
toolchain later disappears.

## Stored in the Git repository

- exact baseline and r5-r8 kernel configurations, including rejected or
  superseded candidate configs;
- the complete five-file r5 source patch, the independent r7 camera PM QoS
  lifecycle patch and the ordered 17-patch r8 c4-c8 series;
- build, repack, temporary-boot, validation and recovery scripts;
- PHH device-hook patch, reversible LineageOS tuning and the measured crDroid
  13 EAS/schedutil profile;
- native AArch64 benchmark source, Android test wrappers, module-CRC and
  memory-pressure tools, plus privacy-reviewed generated r6/r7/r8 summaries;
- module ABI-analysis tools used during development;
- source provenance, the staged 4.9.205 -> 4.9.206 -> 4.9.227 -> 4.9.337
  integration history, failed approaches, security trade-offs and physical
  test boundaries;
- firmware identification and verification metadata, but not Lenovo binaries;
- the X.509 generation recipe required for byte-identical builds.

## Stored as GitHub Release assets

- final flashable r7 image and the qualified r8-c8 pre-release boot image;
- matching raw `Image`, config, `System.map`, `Module.symvers` and generated
  `compile.h`;
- complete corresponding source at r7 commit
  `ca9f99dcda9bc0cf55271157d3a5718ed8cf6e3b`;
- a tagged project archive with every public script, config, patch and document;
- exact Android Clang r365631c and AArch64 GCC 4.9 build toolchains, including
  their license and notice files;
- deliberately public reproducibility key and certificate metadata;
- a privacy-reviewed archive of candidate, ABI, benchmark, memory-pressure,
  permanent-flash and camera evidence;
- a convenient public-artifact bundle and SHA-256 manifest.

v1.4.0-rc1 additionally stores the complete c8 source archive, ordered patch
series and privacy-reviewed c8 validation evidence. All 10 files listed by its
manifest were downloaded again after upload and re-hashed successfully.

Generated `.o` files are not archived individually. They add several gigabytes,
contain absolute local build paths, and can be regenerated from the preserved
source, config, toolchains and reproducibility key. The final generated outputs
needed for diagnosis are preserved separately.

## Preserved outside the public repository

The exact Lenovo factory package
`TB_X505L_USR_S001149_2210181723_Q00015_ROW` is kept as a private recovery
backup. Its public metadata includes the package identity, critical-image
checksums and a verification script. The binary package is not redistributed
because no redistribution grant was found.

Also excluded from public storage:

- device partition backups and factory `boot.img`;
- IMEI, serial number, Android account data, ADB keys and Windows profile
  paths. The fixed `/home/evgen/...` Linux path documented in the build guide
  is retained only because it is an input to byte-identical legacy-kernel
  reproduction; it contains no device or account data;
- proprietary vendor audio/WLAN modules extracted from the tablet;
- screenshots, photographs and UI hierarchy captures;
- third-party APKs and Magisk binaries.

These exclusions do not prevent rebuilding r5, r6, r7 or r8. Repacking a boot image
still requires each owner to provide a matching boot image from their own
device or factory package.
