#!/system/bin/sh
set -u

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <output.txt> <iterations>" >&2
    exit 2
fi

output="$1"
iterations="$2"
package='com.android.settings'
width="$(wm size | tail -n 1 | sed -n 's/.* \([0-9][0-9]*\)x\([0-9][0-9]*\).*/\1/p')"
height="$(wm size | tail -n 1 | sed -n 's/.* \([0-9][0-9]*\)x\([0-9][0-9]*\).*/\2/p')"

case "$width:$height:$iterations" in
    *[!0-9:]*|::*|*:|:*)
        echo "could not parse numeric arguments or display size" >&2
        exit 2
        ;;
esac

x=$((width / 2))
from_y=$((height * 75 / 100))
to_y=$((height * 30 / 100))

: > "$output"
run=1
while [ "$run" -le "$iterations" ]; do
    am force-stop "$package"
    am start -W -a android.settings.SETTINGS >/dev/null
    sleep 2
    dumpsys gfxinfo "$package" reset >/dev/null

    perf_output="${output}.perf-${run}"
    simpleperf stat -a \
        -e cpu-cycles,instructions,cache-references,cache-misses,context-switches,cpu-migrations,page-faults \
        --duration 12 > "$perf_output" 2>&1 &
    perf_pid=$!
    sleep 1

    swipe=0
    while [ "$swipe" -lt 12 ]; do
        input swipe "$x" "$from_y" "$x" "$to_y" 280
        sleep 0.12
        input swipe "$x" "$to_y" "$x" "$from_y" 280
        sleep 0.12
        swipe=$((swipe + 1))
    done
    wait "$perf_pid"

    echo "begin iteration=$run" >> "$output"
    cat "$perf_output" >> "$output"
    dumpsys gfxinfo "$package" | grep -E \
        '^(Total frames rendered|Janky frames:|50th percentile:|90th percentile:|95th percentile:|99th percentile:|Number Missed Vsync:)' \
        >> "$output"
    echo "end iteration=$run" >> "$output"
    rm -f "$perf_output"
    run=$((run + 1))
    sleep 3
done

input keyevent HOME
