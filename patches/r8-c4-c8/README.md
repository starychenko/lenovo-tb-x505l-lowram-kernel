# r8 c4-c8 source series

These 17 mail patches reconstruct the exact c4-c8 source state from the
qualified r8-c3 commit:

```text
base  45a98eac292f8b1fbf6f8e5b1130805691327e68
head  40a80480379791338dfacb3d8a2b3d755c655bad
tree  bff54dc04e870882f0cac4c5b953d73553c30681
```

Apply them in `series` order with `git am`. `SHA256SUMS` covers every patch.
The complete series was applied to the base in a temporary Git index, without
checking out or hashing a second 61-thousand-file worktree; the resulting tree
ID exactly matched the c8 source commit.

The series contains scheduler and KGSL latency work, optimized ARM64 string
paths, the mremap fast path, BFQ v8r10 as a selectable scheduler, the
SDM429-specific KGSL power vote and the A53/ThinLTO compiler candidate.
