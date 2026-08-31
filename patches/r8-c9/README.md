# r8-c9 source patch

This one mail patch advances the exact r8-c8 source state to the final r8-c9
source state:

```text
base  40a80480379791338dfacb3d8a2b3d755c655bad
head  0ea8dc3e34140ac48640f23dacf8b9a04fd2b26e
tree  88f8929f885b45ec856f746a0a3f350efc1d40de
```

It removes the 960 MHz CPU level from the SDM429 cpufreq table, adds the
qualified 364.5 MHz GPU level above the retained 320 MHz level for speed-bin
10, and adds the exact GPLL3 fractional clock entry required to produce it.

Apply it after `patches/r8-c4-c8/` with `git am`. A temporary Git index apply
reconstructed the exact r8-c9 tree ID shown above.
