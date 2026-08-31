# Technical notes

## Device stack

The qualified system combines components from different Android generations:

- Lenovo Android 10 vendor partition and proprietary firmware;
- Linux 4.9.337 r7 kernel with compatibility for the shipping 4.9.205-era
  vendor modules;
- crDroid 9.10 Android 13 PHH GSI system image (with the original Android 11
  qualification retained in `VALIDATION.md`);
- 2 GB physical RAM and a 1 GiB zRAM swap device.

The kernel work first aligned the vendor kernel with modern userspace memory
management, then carried that device behavior forward to 4.9.337 without
replacing the known-working Lenovo hardware modules.

## Memory-management design

### PSI and userspace `lmkd`

Android 10+ can use Pressure Stall Information to tell `lmkd` when tasks are actually delayed by memory contention. The final config enables:

```text
CONFIG_PSI=y
CONFIG_MEMCG=y
CONFIG_MEMCG_SWAP=y
CONFIG_MEMCG_SWAP_ENABLED=y
CONFIG_ANDROID_LOW_MEMORY_KILLER=n
```

Runtime proof was stronger than checking the config: `lmkd` held two writable file descriptors to `/proc/pressure/memory`, and PSI counters changed during the stress test.

### zRAM and LZ4

The GSI creates a 1 GiB zRAM device. The kernel originally offered LZO but not LZ4. r5 enables `CONFIG_CRYPTO_LZ4`, `CONFIG_LZ4_COMPRESS` and `CONFIG_LZ4_DECOMPRESS`, then chooses LZ4 as zRAM's default when compiled in.

Runtime `comp_algorithm` reported:

```text
lzo [lz4] deflate
```

After pressure testing, the final build stored roughly 126.7 MB of original pages in about 39.8 MB of compressed payload, approximately 3.2:1 for that sample. This is a workload observation, not a universal compression guarantee.

### KSM

`CONFIG_KSM=y` was enabled and `/sys/kernel/mm/ksm/run` was verified as `1`. KSM only benefits memory ranges registered as mergeable, so enabling it is not a promise that every app will save RAM.

### `vm.page-cluster=0`

A PHH boot-hook patch sets `vm.page-cluster=0` only when the vendor fingerprint begins with `Lenovo/TB-X505L/`. This prevents the generic GSI from being retuned when reused on another device. The hook affects swap readahead; it does not change the kernel image itself.

## The compound-page reclaim correction

The `/proc` reclaim path originally passed a possibly compound page directly to `isolate_lru_page`. r5 uses `compound_head(page)`, matching the expected LRU object for compound allocations:

```c
if (isolate_lru_page(compound_head(page)))
    continue;
```

## Why rebuilt audio modules were rejected

The first complete source/module build was technically loadable but not functionally equivalent. Loading those audio modules from PHH's later data hook did not register the audio card. The evidence showed that the vendor loads its audio stack during early init, before the late GSI hook, and hardware/ADSP probe events had already occurred by the time the fallback ran.

Using the exact modules already shipped on `/vendor` restored both Lenovo-specific behavior and the original early-init order. The final kernel therefore contains no replacement audio/WLAN modules and no late loader.

## Module CRC compatibility

The public source and generated `Module.symvers` do not exactly match every CRC embedded in Lenovo's shipping modules. A global CRC bypass was tested during development and then rejected as too broad. r5 accepts CRC drift only for these internal module names:

```text
adsp_loader_dlkm
analog_cdc_dlkm
apr_dlkm
cpe_lsm_dlkm
digital_cdc_dlkm
hdmi_dlkm
machine_dlkm
machine_ext_dlkm
mbhc_dlkm
native_dlkm
pinctrl_wcd_dlkm
platform_dlkm
q6_dlkm
q6_notifier_dlkm
stub_dlkm
swr_ctrl_dlkm
swr_dlkm
usf_dlkm
wcd9335_dlkm
wcd9xxx_dlkm
wcd_core_dlkm
wcd_cpe_dlkm
wsa881x_analog_dlkm
wsa881x_dlkm
wlan
```

The compatibility branch calls `add_taint_module(..., TAINT_FORCED_MODULE, ...)` and emits one warning. Normal version enforcement remains in place for all other names.

Three reference vendor-module hashes from the qualified tablet are:

```text
audio_machine_sdm450.ko  2fe5638b1e35c14a732cbf580c6a4931906468fcd1a03d24edd4375e0098e1c9
audio_q6.ko               154d668854d277b5b5ddc1262497a2a9428ebc48f72ee130f8d6cf07cfb7b607
pronto_wlan.ko            19fe7eefc5372391298fd3215e7675dc239828bea891c7db6381124c79ba5486
```

These hashes identify the tested vendor files; the files themselves are not distributed.

## Module signing

The production modules are signed with a key absent from the public source. With strict enforcement, they are rejected even when their code is otherwise compatible. r5 uses permissive signature enforcement, which is standard kernel behavior when `sig_enforce` is false: modules with unavailable keys can load and taint the kernel, while malformed signature blocks are rejected.

This part is global, unlike the CRC allowlist. It is the largest security cost of the build and is documented prominently rather than hidden.

Taint `12290` is `0x3002`, corresponding to forced module (`F`), out-of-tree module (`O`) and unsigned/untrusted-key module (`E`).

## Changes deliberately not made

- No CPU or GPU overclocking.
- No undervolting.
- No thermal-limit removal.
- No speculative scheduler/governor tuning without repeatable latency and battery measurements.
- No new DTB.
- No replacement vendor firmware.
- No permanent root-hiding or payment-integrity bypass.

Those changes can make benchmark numbers look better while reducing stability,
battery life or hardware safety. The project scope is low-memory behavior,
measured compatibility and conservative upstream integration proven on the
actual device.
