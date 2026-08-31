#!/system/bin/sh
set -u

state_file='/data/local/tmp/tb-x505l-runtime-profile.state'

nodes='
/dev/stune/top-app/schedtune.boost
/dev/stune/top-app/schedtune.prefer_idle
/dev/stune/foreground/schedtune.boost
/dev/stune/foreground/schedtune.prefer_idle
/sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq
/sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load
/sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us
/sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us
'

show_values() {
    for node in $nodes; do
        if [ -r "$node" ]; then
            value=''
            IFS= read -r value < "$node" || true
            printf '%s=%s\n' "$node" "$value"
        else
            printf '%s=UNAVAILABLE\n' "$node"
        fi
    done
}

write_checked() {
    node="$1"
    requested="$2"
    if [ ! -w "$node" ]; then
        echo "not writable: $node" >&2
        exit 1
    fi
    printf '%s' "$requested" > "$node"
    actual=''
    IFS= read -r actual < "$node" || true
    if [ "$actual" != "$requested" ]; then
        echo "verification failed: $node requested=$requested actual=$actual" >&2
        exit 1
    fi
}

capture_state() {
    : > "$state_file"
    for node in $nodes; do
        if [ ! -r "$node" ]; then
            echo "cannot capture: $node" >&2
            rm -f "$state_file"
            exit 1
        fi
        value=''
        IFS= read -r value < "$node" || true
        printf '%s|%s\n' "$node" "$value" >> "$state_file"
    done
}

begin_profile() {
    if [ -e "$state_file" ]; then
        echo "state already exists; restore it before applying another profile" >&2
        exit 1
    fi
    capture_state
}

apply_eas_ui() {
    begin_profile
    write_checked /dev/stune/top-app/schedtune.boost 10
    write_checked /dev/stune/top-app/schedtune.prefer_idle 1
    write_checked /dev/stune/foreground/schedtune.boost 5
    write_checked /dev/stune/foreground/schedtune.prefer_idle 1
    echo 'profile=eas-ui status=applied'
    show_values
}

apply_schedutil_ui() {
    begin_profile
    write_checked /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq 1497600
    write_checked /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load 75
    write_checked /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us 0
    write_checked /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us 20000
    echo 'profile=schedutil-ui status=applied'
    show_values
}

apply_balanced_ui() {
    begin_profile
    write_checked /dev/stune/top-app/schedtune.boost 10
    write_checked /dev/stune/top-app/schedtune.prefer_idle 1
    write_checked /dev/stune/foreground/schedtune.boost 5
    write_checked /dev/stune/foreground/schedtune.prefer_idle 1
    write_checked /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq 1497600
    write_checked /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load 75
    write_checked /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us 0
    write_checked /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us 20000
    echo 'profile=balanced-ui status=applied'
    show_values
}

restore_state() {
    if [ ! -r "$state_file" ]; then
        echo "no saved state: $state_file" >&2
        exit 1
    fi
    while IFS='|' read -r node value; do
        [ -n "$node" ] || continue
        write_checked "$node" "$value"
    done < "$state_file"
    rm -f "$state_file"
    echo 'profile=baseline status=restored'
    show_values
}

case "${1:-show}" in
    show)
        show_values
        ;;
    apply-balanced-ui)
        apply_balanced_ui
        ;;
    apply-eas-ui)
        apply_eas_ui
        ;;
    apply-schedutil-ui)
        apply_schedutil_ui
        ;;
    restore)
        restore_state
        ;;
    *)
        echo "usage: $0 {show|apply-eas-ui|apply-schedutil-ui|apply-balanced-ui|restore}" >&2
        exit 2
        ;;
esac
