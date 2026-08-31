# Abandoned rebuilt-module overlay

This directory preserves an engineering approach that booted but was rejected
for the final release. It attempted to bind-mount rebuilt audio/WLAN modules over
`/vendor/lib/modules` from PHH's early data hook.

It was abandoned because the hook ran after the vendor's original hardware
probe order. Audio devices that had already failed to probe did not recover
reliably when replacement modules appeared later. The rebuilt modules also did
not reproduce all Lenovo metadata and device-specific behavior.

The scripts and the minimal `phh-on-data-module-hook.patch` are retained as
research evidence, not installation instructions. The complete PHH base file is
referenced by pinned upstream commit/blob rather than duplicated here:

```text
commit: 41f0817f3fab4361216c5e3bce3660c5045f665b
phh-on-data.sh blob: 472d16ea8997af3235138a6fcf39b11dc689907b
```

The corresponding module binaries are stored only in the clearly marked
engineering-history release archive and must not be mixed with r5. Final r5
instead keeps the stock vendor modules and uses a narrow 25-name CRC
compatibility allowlist in the kernel.
