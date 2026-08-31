#!/system/bin/sh

# TB-X505L r8 feature-pack regression test. The default mode is read-only.
# Pass "active" to exercise reversible KCAL, qdisc, TCP and Bluetooth paths.
# Pass "production" to run those tests and require the qualified runtime
# profile to have been applied after boot.

set -u

mode="${1:-read-only}"
case "$mode" in
    read-only|active|production) ;;
    *)
        echo "Usage: $0 [read-only|active|production]" >&2
        exit 2
        ;;
esac

failures=0

pass() {
    printf 'PASS %-28s %s\n' "$1" "${2:-}"
}

fail() {
    printf 'FAIL %-28s %s\n' "$1" "${2:-}"
    failures=$((failures + 1))
}

expect_word() {
    label="$1"
    word="$2"
    value="$3"
    case " $value " in
        *" $word "*) pass "$label" "$word" ;;
        *) fail "$label" "missing $word in: $value" ;;
    esac
}

expect_value() {
    label="$1"
    node="$2"
    expected="$3"
    if [ ! -r "$node" ]; then
        fail "$label" "unavailable: $node"
        return
    fi
    actual="$(cat "$node")"
    if [ "$actual" = "$expected" ]; then
        pass "$label" "$actual"
    else
        fail "$label" "expected=$expected actual=$actual"
    fi
}

release="$(uname -r)"
case "$release" in
    *tbx505l-r8-*) pass kernel_release "$release" ;;
    *) fail kernel_release "$release" ;;
esac

case "$release" in
    *tbx505l-r8-fastpath-c3*)
        expect_value compact_unevictable \
            /proc/sys/vm/compact_unevictable_allowed 0
        if [ "$(cat /sys/bus/i2c/devices/3-005d/name 2>/dev/null)" = "gt9xx" ] &&
           [ "$(cat /sys/class/i2c-adapter/i2c-3/name 2>/dev/null)" = "MSM-I2C-v2-adapter" ]; then
            pass goodix_i2c_path gt9xx/MSM-I2C-v2
        else
            fail goodix_i2c_path unexpected
        fi
        ;;
esac

boot_completed="$(getprop sys.boot_completed)"
if [ "$boot_completed" = "1" ]; then
    pass android_boot_completed 1
else
    fail android_boot_completed "$boot_completed"
fi

module_count="$(wc -l < /proc/modules | tr -d ' ')"
if [ "$module_count" = "25" ]; then
    pass vendor_modules "$module_count loaded"
else
    fail vendor_modules "$module_count loaded; expected 25"
fi

if grep -Fq 'sdm439-snd-card-mtp' /proc/asound/cards; then
    pass audio_card sdm439-snd-card-mtp
else
    fail audio_card missing
fi

if ip link show wlan0 2>/dev/null | grep -q 'state UP'; then
    pass wifi_interface UP
else
    fail wifi_interface not-up
fi

if dumpsys media.camera 2>/dev/null | grep -Fq 'Number of camera devices: 2'; then
    pass camera_devices 2
else
    fail camera_devices unexpected
fi

if dumpsys sensorservice 2>/dev/null | grep -Fq 'MC34XX ACCELEROMETER'; then
    pass accelerometer MC34XX
else
    fail accelerometer missing
fi

for symbol in \
    CONFIG_COMPAT_VDSO=y \
    CONFIG_THUMB2_COMPAT_VDSO=y \
    CONFIG_TCP_CONG_BBR=y \
    CONFIG_TCP_CONG_WESTWOOD=y \
    CONFIG_NET_SCH_FQ_CODEL=y \
    CONFIG_NET_SCH_FQ=y \
    CONFIG_FB_MSM_MDSS_KCAL_CTRL=y \
    CONFIG_ARM_ARCH_TIMER_VCT_ACCESS=y \
    CONFIG_IOSCHED_BFQ=y \
    CONFIG_ARCH_SUPPORTS_OPTIMIZED_INLINING=y \
    CONFIG_OPTIMIZE_INLINING=y \
    CONFIG_ARM64_TUNE_CORTEX_A53=y \
    CONFIG_THIN_ARCHIVES=y \
    CONFIG_LTO=y \
    CONFIG_LTO_CLANG=y
do
    if zcat /proc/config.gz 2>/dev/null | grep -Fqx "$symbol"; then
        pass kernel_config "$symbol"
    else
        fail kernel_config "$symbol"
    fi
done

block_schedulers="$(cat /sys/block/mmcblk0/queue/scheduler 2>/dev/null)"
expect_word scheduler_bfq bfq "$block_schedulers"
case "$block_schedulers" in
    *'[deadline]'*) pass scheduler_default deadline ;;
    *) fail scheduler_default "expected deadline in: $block_schedulers" ;;
esac

expect_value kgsl_active_latency \
    /sys/class/kgsl/kgsl-3d0/pmqos_active_latency 1000

available_cc="$(cat /proc/sys/net/ipv4/tcp_available_congestion_control)"
expect_word congestion_bbr bbr "$available_cc"
expect_word congestion_westwood westwood "$available_cc"

for qdisc in fq fq_codel; do
    if grep -Fq " $qdisc " /proc/kallsyms 2>/dev/null ||
       zcat /proc/config.gz 2>/dev/null | grep -Fqx "CONFIG_NET_SCH_$(printf '%s' "$qdisc" | tr '[:lower:]' '[:upper:]')=y"; then
        pass "qdisc_$qdisc" built-in
    else
        fail "qdisc_$qdisc" missing
    fi
done

kcal_base=/sys/devices/platform/kcal_ctrl.0
for attribute in kcal kcal_min kcal_enable kcal_sat kcal_hue kcal_val kcal_cont; do
    if [ -r "$kcal_base/$attribute" ]; then
        pass "kcal_$attribute" "$(cat "$kcal_base/$attribute")"
    else
        fail "kcal_$attribute" missing
    fi
done

for cache in binder_buffer binder_node binder_proc binder_ref binder_ref_death binder_thread binder_transaction binder_work; do
    if [ -e "/sys/kernel/slab/$cache" ]; then
        pass "slab_$cache" present
    else
        fail "slab_$cache" missing
    fi
done

vdso32_count=0
vdso32_examples=0
for process in /proc/[0-9]*; do
    [ -r "$process/exe" ] || continue
    elf_class="$(od -An -t u1 -j4 -N1 "$process/exe" 2>/dev/null | tr -d ' ')"
    [ "$elf_class" = "1" ] || continue
    vdso_line="$(grep '\[vdso\]' "$process/maps" 2>/dev/null | head -n 1)"
    [ -n "$vdso_line" ] || continue
    vdso32_count=$((vdso32_count + 1))
    if [ "$vdso32_examples" -lt 3 ]; then
        printf 'INFO vdso32_process              %s %s\n' \
            "$(readlink "$process/exe" 2>/dev/null)" "$vdso_line"
        vdso32_examples=$((vdso32_examples + 1))
    fi
done
if [ "$vdso32_count" -gt 0 ]; then
    pass live_vdso32_processes "$vdso32_count"
else
    fail live_vdso32_processes 0
fi

if [ "$mode" = "production" ]; then
    expect_value profile_top_app_boost \
        /dev/stune/top-app/schedtune.boost 10
    expect_value profile_top_app_idle \
        /dev/stune/top-app/schedtune.prefer_idle 1
    expect_value profile_foreground_boost \
        /dev/stune/foreground/schedtune.boost 5
    expect_value profile_foreground_idle \
        /dev/stune/foreground/schedtune.prefer_idle 1
    expect_value profile_hispeed_freq \
        /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq 1497600
    expect_value profile_hispeed_load \
        /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load 75
    expect_value profile_up_rate_limit \
        /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us 0
    expect_value profile_down_rate_limit \
        /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us 20000
    expect_value profile_schedstats \
        /proc/sys/kernel/sched_schedstats 0
fi

if [ "$mode" != "read-only" ]; then
    old_tcp="$(cat /proc/sys/net/ipv4/tcp_congestion_control)"
    old_root_qdisc="$(tc qdisc show dev wlan0 2>/dev/null | awk 'NR == 1 { print $2 }')"
    old_bluetooth="$(settings get global bluetooth_on)"
    restored=0

    restore_runtime() {
        [ "$restored" = "1" ] && return
        sysctl -w "net.ipv4.tcp_congestion_control=$old_tcp" >/dev/null 2>&1 || true
        if [ -n "$old_root_qdisc" ]; then
            tc qdisc replace dev wlan0 root "$old_root_qdisc" >/dev/null 2>&1 || true
        fi
        if [ "$old_bluetooth" = "1" ]; then
            cmd bluetooth_manager enable >/dev/null 2>&1 || true
            cmd bluetooth_manager wait-for-state:STATE_ON >/dev/null 2>&1 || true
        else
            cmd bluetooth_manager disable >/dev/null 2>&1 || true
            cmd bluetooth_manager wait-for-state:STATE_OFF >/dev/null 2>&1 || true
        fi
        restored=1
    }
    trap restore_runtime EXIT INT TERM

    kcal_ok=1
    for attribute in kcal kcal_min kcal_sat kcal_hue kcal_val kcal_cont; do
        value="$(cat "$kcal_base/$attribute" 2>/dev/null)" || kcal_ok=0
        echo "$value" > "$kcal_base/$attribute" 2>/dev/null || kcal_ok=0
        current="$(cat "$kcal_base/$attribute" 2>/dev/null)" || kcal_ok=0
        if [ "$current" != "$value" ]; then
            printf 'INFO kcal_mismatch               %s before=%s after=%s\n' \
                "$attribute" "$value" "$current"
            kcal_ok=0
        fi
    done
    if [ "$kcal_ok" = "1" ]; then
        pass kcal_noop_write restored
    else
        fail kcal_noop_write mismatch
    fi

    if tc qdisc replace dev wlan0 root fq_codel >/dev/null 2>&1 &&
       tc qdisc show dev wlan0 2>/dev/null | grep -q '^qdisc fq_codel ' &&
       sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 &&
       ping -c 2 -W 2 1.1.1.1 >/dev/null 2>&1; then
        pass active_fq_codel_bbr traffic-ok
    else
        fail active_fq_codel_bbr failed
    fi

    if tc qdisc replace dev wlan0 root fq >/dev/null 2>&1 &&
       tc qdisc show dev wlan0 2>/dev/null | grep -q '^qdisc fq ' &&
       sysctl -w net.ipv4.tcp_congestion_control=westwood >/dev/null 2>&1 &&
       ping -c 2 -W 2 1.1.1.1 >/dev/null 2>&1; then
        pass active_fq_westwood traffic-ok
    else
        fail active_fq_westwood failed
    fi

    if cmd bluetooth_manager enable >/dev/null 2>&1 &&
       cmd bluetooth_manager wait-for-state:STATE_ON >/dev/null 2>&1 &&
       [ "$(settings get global bluetooth_on)" = "1" ]; then
        pass active_bluetooth STATE_ON
    else
        fail active_bluetooth failed
    fi

    restore_runtime
    trap - EXIT INT TERM

    current_tcp="$(cat /proc/sys/net/ipv4/tcp_congestion_control)"
    current_root_qdisc="$(tc qdisc show dev wlan0 2>/dev/null | awk 'NR == 1 { print $2 }')"
    current_bluetooth="$(settings get global bluetooth_on)"
    if [ "$current_tcp" = "$old_tcp" ] &&
       [ "$current_root_qdisc" = "$old_root_qdisc" ] &&
       [ "$current_bluetooth" = "$old_bluetooth" ]; then
        pass runtime_restore "$old_tcp/$old_root_qdisc/bt=$old_bluetooth"
    else
        fail runtime_restore "$current_tcp/$current_root_qdisc/bt=$current_bluetooth"
    fi
fi

critical_log="$(dmesg 2>/dev/null | grep -E \
    'Unknown symbol|disagrees about version|Kernel panic|Oops:|BUG:|Call trace|Unable to handle|hung task|Out of memory|oom-kill|KASAN|use-after-free' || true)"
if [ -z "$critical_log" ]; then
    pass critical_kernel_log clean
else
    fail critical_kernel_log matches-found
    printf '%s\n' "$critical_log"
fi

if [ "$failures" -eq 0 ]; then
    echo 'RESULT=PASS'
    exit 0
fi

echo "RESULT=FAIL failures=$failures"
exit 1
