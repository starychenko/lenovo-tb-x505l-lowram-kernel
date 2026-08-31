# Security policy and limitations

This project is an experimental community kernel for an old tablet platform. It is not a security-maintained Android distribution.

## Important limitations

- Kernel 4.9 and the tested vendor image are old and do not receive current security fixes here.
- The bootloader must be unlocked, which changes the device's physical-security model.
- Lenovo's module-signing private key is unavailable. Every project release,
  including r7, runs module-signature verification in permissive mode so the
  stock vendor modules can load.
- A user with root can therefore load an unsigned kernel module. Malformed signatures are still rejected.
- The release's build-generated reproducibility key is deliberately public. It
  is not Lenovo's key, an Android verified-boot key or an account credential.
  Since unsigned modules are already accepted with taint, this does not widen
  the effective module-loading boundary; do not reuse the key elsewhere.
- CRC drift is bypassed only for 25 explicit Lenovo audio/WLAN module names, but the signing policy itself is globally permissive.
- This kernel is unsuitable for a payment terminal, password vault, work-profile device or other high-value security boundary.

## Reporting

Do not publish device identifiers, account data or proprietary firmware in an issue. A useful report contains:

- exact model and vendor build;
- GSI/ROM name and Android version;
- whether the image was temporary-booted or flashed;
- `uname -a`;
- relevant `dmesg` lines with identifiers removed;
- whether the stock boot image restores the behavior.

Use a normal GitHub issue for kernel defects. This repository does not promise embargoed vulnerability handling.
