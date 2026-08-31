#!/system/bin/sh
set -u

tag='tb-x505l-profile'

nodes='
/dev/stune/top-app/schedtune.boost|10
/dev/stune/top-app/schedtune.prefer_idle|1
/dev/stune/foreground/schedtune.boost|5
/dev/stune/foreground/schedtune.prefer_idle|1
/sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq|1497600
/sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load|75
/sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us|0
/sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us|20000
'

report() {
    printf '%s\n' "$*"
    log -t "$tag" "$*" 2>/dev/null || true
}

read_node() {
    node="$1"
    if [ ! -r "$node" ]; then
        printf '%s=UNAVAILABLE\n' "$node"
        return
    fi

    value=''
    IFS= read -r value < "$node" || true
    printf '%s=%s\n' "$node" "$value"
}

show_values() {
    old_ifs="$IFS"
    IFS='
'
    for item in $nodes; do
        [ -n "$item" ] || continue
        node="${item%%\|*}"
        read_node "$node"
    done
    IFS="$old_ifs"
}

device_is_supported() {
    fingerprint="$(getprop ro.vendor.build.fingerprint)"
    case "$fingerprint" in
        Lenovo/TB-X505L/*) ;;
        *)
            report "skip: unsupported vendor fingerprint: $fingerprint"
            return 1
            ;;
    esac

    kernel_release="$(uname -r)"
    case "$kernel_release" in
        *tbx505l-r6*|*tbx505l-r7*) ;;
        *)
            report "skip: profile requires a qualified TB-X505L r6/r7 kernel: $kernel_release"
            return 1
            ;;
    esac
}

write_checked() {
    node="$1"
    requested="$2"

    if [ ! -w "$node" ]; then
        report "error: node is not writable: $node"
        return 1
    fi

    printf '%s' "$requested" > "$node"
    actual=''
    IFS= read -r actual < "$node" || true
    if [ "$actual" != "$requested" ]; then
        report "error: verification failed: $node requested=$requested actual=$actual"
        return 1
    fi

    report "set: $node=$actual"
}

apply_profile() {
    device_is_supported || return 0

    failures=0
    old_ifs="$IFS"
    IFS='
'
    for item in $nodes; do
        [ -n "$item" ] || continue
        node="${item%%\|*}"
        requested="${item#*\|}"
        write_checked "$node" "$requested" || failures=$((failures + 1))
    done
    IFS="$old_ifs"

    if [ "$failures" -ne 0 ]; then
        report "profile=balanced-ui status=failed failures=$failures"
        return 1
    fi

    report 'profile=balanced-ui status=applied'
}

apply_late() {
    attempts=0
    while [ "$(getprop sys.boot_completed)" != '1' ] && [ "$attempts" -lt 60 ]; do
        sleep 2
        attempts=$((attempts + 1))
    done

    if [ "$(getprop sys.boot_completed)" != '1' ]; then
        report 'error: Android did not report a completed boot within 120 seconds'
        return 1
    fi

    # Give PowerHAL and init late property actions time to publish their final
    # governor policy before the tested values are applied.
    sleep 5
    apply_profile
}

case "${1:-show}" in
    apply)
        apply_profile
        ;;
    apply-late)
        apply_late
        ;;
    show)
        show_values
        ;;
    *)
        echo "usage: $0 {apply|apply-late|show}" >&2
        exit 2
        ;;
esac
