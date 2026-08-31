#!/system/bin/sh

# Read-only runtime snapshot for the TB-X505L kernel/tuning work.
# Run as root so vendor sysfs nodes are visible. The script does not change
# properties, sysctls, governors, clocks, partitions, or files on the tablet.

section() {
    printf '\n## %s\n' "$1"
}

read_value() {
    label="$1"
    path="$2"
    if [ -r "$path" ]; then
        printf '%s=' "$label"
        cat "$path"
    else
        printf '%s=<unavailable>\n' "$label"
    fi
}

section identity
date -u 2>/dev/null || true
uname -a
id
printf 'fingerprint='; getprop ro.build.fingerprint
printf 'vendor_fingerprint='; getprop ro.vendor.build.fingerprint
printf 'bootimage_fingerprint='; getprop ro.bootimage.build.fingerprint
printf 'boot_completed='; getprop sys.boot_completed
printf 'uptime='; cat /proc/uptime
printf 'cmdline='; cat /proc/cmdline

section memory
grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapCached|SwapTotal|SwapFree|SReclaimable|Shmem):' /proc/meminfo
for pressure in cpu memory io; do
    read_value "pressure_${pressure}" "/proc/pressure/${pressure}"
done
for vm_name in swappiness page-cluster dirty_background_ratio dirty_ratio dirty_expire_centisecs dirty_writeback_centisecs min_free_kbytes watermark_scale_factor overcommit_memory; do
    read_value "vm_${vm_name}" "/proc/sys/vm/${vm_name}"
done

section zram
for zram_path in /sys/block/zram*; do
    [ -e "$zram_path" ] || continue
    printf 'device=%s\n' "$zram_path"
    for name in disksize comp_algorithm max_comp_streams mem_limit mem_used_total compr_data_size orig_data_size same_pages huge_pages mm_stat io_stat; do
        read_value "$name" "$zram_path/$name"
    done
done

section ksm
for name in run pages_shared pages_sharing pages_unshared pages_volatile full_scans sleep_millisecs pages_to_scan merge_across_nodes; do
    read_value "$name" "/sys/kernel/mm/ksm/${name}"
done

section cpu
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -e "$policy" ] || continue
    printf 'policy=%s\n' "$policy"
    for name in affected_cpus related_cpus scaling_driver scaling_governor scaling_available_governors scaling_available_frequencies scaling_min_freq scaling_max_freq scaling_cur_freq cpuinfo_min_freq cpuinfo_max_freq cpuinfo_cur_freq; do
        read_value "$name" "$policy/$name"
    done
    for tunable in "$policy"/schedutil/*; do
        [ -f "$tunable" ] || continue
        read_value "schedutil_$(basename "$tunable")" "$tunable"
    done
done
for cpu_path in /sys/devices/system/cpu/cpu[0-9]*; do
    [ -d "$cpu_path/core_ctl" ] || continue
    printf 'core_ctl=%s\n' "$cpu_path"
    for name in enable min_cpus max_cpus offline_delay_ms busy_up_thres busy_down_thres task_thres is_big_cluster nr_isolated_cpus need_cpus; do
        read_value "$name" "$cpu_path/core_ctl/$name"
    done
done
for boost_path in /sys/module/cpu_boost/parameters/* /sys/module/msm_performance/parameters/*; do
    [ -f "$boost_path" ] || continue
    read_value "module_$(basename "$(dirname "$boost_path")")_$(basename "$boost_path")" "$boost_path"
done

section schedtune
for group in /dev/stune/*; do
    [ -d "$group" ] || continue
    printf 'group=%s\n' "$group"
    read_value boost "$group/schedtune.boost"
    read_value prefer_idle "$group/schedtune.prefer_idle"
done

section gpu
gpu_path=/sys/class/kgsl/kgsl-3d0
for name in gpu_available_frequencies gpuclk min_gpuclk max_gpuclk num_pwrlevels active_pwrlevel default_pwrlevel min_pwrlevel max_pwrlevel thermal_pwrlevel force_clk_on force_bus_on force_rail_on idle_timer gpu_busy_percentage gpubusy; do
    read_value "$name" "$gpu_path/$name"
done
for name in governor available_governors available_frequencies min_freq max_freq cur_freq polling_interval; do
    read_value "devfreq_${name}" "$gpu_path/devfreq/$name"
done

section storage
for block_path in /sys/block/mmcblk0 /sys/block/sda; do
    [ -e "$block_path" ] || continue
    printf 'block=%s\n' "$block_path"
    for name in scheduler read_ahead_kb nr_requests rq_affinity iostats add_random rotational nomerges; do
        read_value "$name" "$block_path/queue/$name"
    done
done

section thermal
for zone in /sys/class/thermal/thermal_zone*; do
    [ -e "$zone" ] || continue
    printf 'zone=%s type=' "$zone"
    cat "$zone/type" 2>/dev/null || printf '<unavailable>\n'
    read_value temp "$zone/temp"
    read_value mode "$zone/mode"
done

section relevant_processes
ps -A -o USER,PID,NAME,ARGS 2>/dev/null | grep -Ei '(^USER|lmkd|thermal|power|perfd|mpdecision)' || true

section relevant_properties
getprop | grep -Ei '(lmk|low_ram|power|thermal|zram|dalvik.vm|hwui)' || true

section modules
printf 'module_count='; wc -l < /proc/modules
cut -d ' ' -f 1,3-6 /proc/modules

section kernel_log_tail
dmesg 2>/dev/null | tail -n 120 || true
