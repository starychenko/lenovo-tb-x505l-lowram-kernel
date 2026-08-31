# Byte-for-byte reproducibility key

The kernel configuration embeds an X.509 certificate. If no key is supplied,
the Linux build creates a random key pair and otherwise identical builds have a
different `Image` hash.

The release therefore contains `tb-x505l-r5-reproducibility-key.tar.gz`. Its
`signing_key.pem` is the build-generated key used for r5. It is deliberately
public and is not a Lenovo production key, a user credential, or an Android
verified-boot key. The matching certificate is already embedded in the released
kernel.

This project also makes module-signature enforcement permissive because the
Lenovo production key is unavailable. Publishing this build key therefore does
not turn an otherwise rejected unsigned module into an accepted one; unsigned
modules are already accepted with a kernel taint. Do not reuse this key for any
other trust domain.

Pass the unpacked `signing_key.pem` as the fifth argument to
`scripts/build-kernel.sh` to reproduce the released `Image` byte for byte.
