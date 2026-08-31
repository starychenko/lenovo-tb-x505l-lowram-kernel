# Lenovo factory firmware identification

The tested vendor and recovery stack came from:

```text
Model: Lenovo TB-X505L
Package: TB_X505L_USR_S001149_2210181723_Q00015_ROW
Android: 10
Display build: TB-X505L_S001149_221018_ROW
```

The factory package is not part of this repository. A file being downloadable
does not itself grant redistribution rights. Obtain the package through Lenovo's
official Software Fix / Rescue and Smart Assistant workflow, then verify it with
`scripts/verify-lenovo-firmware.ps1` and
`TB-X505L-S001149-critical-sha256.txt`. The verifier accepts either the
directory containing the package's `image` folder or the `image` folder itself.

Do not substitute a TB-X505F, TB-X505X or another regional/build package. The
kernel release was qualified against this exact vendor build.

The private recovery archive is split into independently hashable parts for
storage outside GitHub. Its part hashes and exact reconstruction command are
stored beside the private backup, so corruption can be detected before
reconstruction. The public critical-file manifest can then confirm that the
reconstructed package is the exact S001149 build qualified here.

Maintainer recovery copy:
[private Google Drive folder](https://drive.google.com/drive/folders/1h43LaM_2DC68PRuCZ3WuSSS9SR9NFjTV).
At publication time it contains three archive parts plus checksums, restore
instructions and verification scripts, and Google reports it as not shared.
The link is recorded for owner recovery; it is not a public firmware download.
