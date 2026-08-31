# Preservation and publication inventory

This project is preserved as more than a single flashable image. The public
release is designed to remain useful even if an upstream branch or prebuilt
toolchain later disappears.

## Stored in the Git repository

- exact baseline and r5 kernel configurations;
- the complete five-file r5 source patch;
- build, repack, temporary-boot, validation and recovery scripts;
- PHH device-hook patch and reversible LineageOS tuning;
- module ABI-analysis tools used during development;
- source provenance, failed approaches, security trade-offs and physical test
  boundaries;
- firmware identification and verification metadata, but not Lenovo binaries;
- the X.509 generation recipe required for byte-identical builds.

## Stored as GitHub Release assets

- final flashable boot image and raw kernel `Image`;
- config, `System.map`, `Module.symvers` and generated `compile.h`;
- exact frozen Lenovo/CAF base source archive;
- complete corresponding source with r5 already applied;
- exact Android Clang r365631c and AArch64 GCC 4.9 build toolchains, including
  their license and notice files;
- deliberately public r5 reproducibility key and certificate metadata;
- a clearly marked archive of non-release engineering kernel outputs and build
  evidence;
- a convenient public-artifact bundle and SHA-256 manifest.

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

These exclusions do not prevent rebuilding r5. Repacking a boot image still
requires each owner to provide a matching boot image from their own device or
factory package.
