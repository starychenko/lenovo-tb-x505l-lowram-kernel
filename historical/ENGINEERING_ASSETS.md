# Unsupported engineering assets

The `tb-x505l-engineering-history.tar.gz` release asset preserves selected
intermediate outputs from the investigation: raw kernels, configurations,
symbol maps, module-version tables, public-source rebuilt modules and sanitized
build evidence. It exists so later developers can reproduce the path to r5 and
compare rejected approaches.

These files are **not releases and must not be flashed blindly**. Some builds
were abandoned because they failed to boot, did not retain Lenovo's vendor
module ABI, or depended on a late module-overlay experiment that did not restore
audio reliably. Use the final r5 boot image for the tested configuration.

The archive intentionally excludes Lenovo factory images, extracted proprietary
vendor modules, device partition backups, personal identifiers, ADB keys,
screenshots, APKs and Magisk binaries.
