#!/system/bin/sh
set -u

if [ "$#" -lt 2 ]; then
    echo "usage: $0 <telemetry.csv> <command> [args...]" >&2
    exit 2
fi

telemetry="$1"
shift

read_value() {
    if [ -r "$1" ]; then
        value=''
        IFS= read -r value < "$1" || true
        printf '%s' "${value:-NA}"
    else
        printf 'NA'
    fi
}

thermal_max() {
    maximum=0
    found=0
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        [ -r "$zone" ] || continue
        value=''
        IFS= read -r value < "$zone" || true
        case "$value" in
            ''|*[!0-9-]*) continue ;;
        esac
        if [ "$found" -eq 0 ] || [ "$value" -gt "$maximum" ]; then
            maximum="$value"
            found=1
        fi
    done
    if [ "$found" -eq 1 ]; then
        printf '%s' "$maximum"
    else
        printf 'NA'
    fi
}

gpu_frequency() {
    for node in \
        /sys/class/kgsl/kgsl-3d0/gpuclk \
        /sys/class/devfreq/1c00000.qcom,kgsl-3d0/cur_freq \
        /sys/class/devfreq/1c00000.qcom,kgsl-3d0/device/clock_mhz; do
        if [ -r "$node" ]; then
            read_value "$node"
            return
        fi
    done
    printf 'NA'
}

psi_value() {
    if [ -r /proc/pressure/memory ]; then
        awk '/^some / { for (i=1; i<=NF; i++) if ($i ~ /^avg10=/) { sub(/^avg10=/, "", $i); print $i; exit } }' /proc/pressure/memory
    else
        printf 'NA'
    fi
}

echo 'monotonic_s,cpu0_khz,cpu1_khz,cpu2_khz,cpu3_khz,gpu_hz,thermal_max_millic,battery_current_ua,mem_available_kib,swap_free_kib,psi_memory_some_avg10,context_switches,pgmajfault,pswpin,pswpout' > "$telemetry"
stop_file="${telemetry}.stop"
rm -f "$stop_file"

(
    while [ ! -e "$stop_file" ]; do
        timestamp="$(cut -d' ' -f1 /proc/uptime)"
        mem_available="$(awk '/^MemAvailable:/ { print $2; exit }' /proc/meminfo)"
        swap_free="$(awk '/^SwapFree:/ { print $2; exit }' /proc/meminfo)"
        context_switches="$(awk '/^ctxt / { print $2; exit }' /proc/stat)"
        pgmajfault="$(awk '$1 == "pgmajfault" { print $2; exit }' /proc/vmstat)"
        pswpin="$(awk '$1 == "pswpin" { print $2; exit }' /proc/vmstat)"
        pswpout="$(awk '$1 == "pswpout" { print $2; exit }' /proc/vmstat)"
        printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
            "$timestamp" \
            "$(read_value /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)" \
            "$(read_value /sys/devices/system/cpu/cpu1/cpufreq/scaling_cur_freq)" \
            "$(read_value /sys/devices/system/cpu/cpu2/cpufreq/scaling_cur_freq)" \
            "$(read_value /sys/devices/system/cpu/cpu3/cpufreq/scaling_cur_freq)" \
            "$(gpu_frequency)" \
            "$(thermal_max)" \
            "$(read_value /sys/class/power_supply/battery/current_now)" \
            "${mem_available:-NA}" \
            "${swap_free:-NA}" \
            "$(psi_value)" \
            "${context_switches:-NA}" \
            "${pgmajfault:-NA}" \
            "${pswpin:-NA}" \
            "${pswpout:-NA}"
        sleep 1
    done
) >> "$telemetry" &
monitor_pid=$!

"$@"
status=$?

: > "$stop_file"
wait "$monitor_pid" 2>/dev/null || true
rm -f "$stop_file"
exit "$status"
