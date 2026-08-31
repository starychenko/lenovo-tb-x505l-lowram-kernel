#!/system/bin/sh
set -eu

usage() {
    echo "Usage: $0 <benchmark-binary> <per-worker-MiB> <rounds> <workers> <output-dir>" >&2
}

if [ "$#" -ne 5 ]; then
    usage
    exit 2
fi

binary="$1"
per_worker_mib="$2"
rounds="$3"
workers="$4"
output_dir="$5"

case "$output_dir" in
    /data/local/tmp/tbx-memory-pressure-*) ;;
    *)
        echo "Output directory must be a dedicated /data/local/tmp/tbx-memory-pressure-* path." >&2
        exit 2
        ;;
esac

if [ ! -x "$binary" ]; then
    echo "Benchmark binary is not executable: $binary" >&2
    exit 1
fi

for value in "$per_worker_mib" "$rounds" "$workers"; do
    case "$value" in
        ''|*[!0-9]*)
            echo "Numeric arguments must be positive integers." >&2
            exit 2
            ;;
        0)
            echo "Numeric arguments must be greater than zero." >&2
            exit 2
            ;;
    esac
done

if [ -e "$output_dir" ]; then
    echo "Refusing to reuse existing output directory: $output_dir" >&2
    exit 1
fi
mkdir "$output_dir"

snapshot() {
    destination="$1"
    {
        date
        uname -a
        grep -E '^(MemTotal|MemFree|MemAvailable|Cached|SwapCached|SwapTotal|SwapFree|AnonPages|Slab|SReclaimable|SUnreclaim|CmaTotal|CmaFree):' /proc/meminfo
        printf '%s\n' '=== VMSTAT ==='
        grep -E '^(pswpin|pswpout|pgmajfault|pgscan_kswapd|pgsteal_kswapd) ' /proc/vmstat
        printf '%s\n' '=== ZRAM ==='
        cat /sys/block/zram0/mm_stat 2>/dev/null || true
        printf '%s\n' '=== MEMORY PSI ==='
        cat /proc/pressure/memory 2>/dev/null || true
    } > "$destination"
}

snapshot "$output_dir/before.txt"
printf '%s\n' 'epoch,mem_available_kb,swap_free_kb,zram_used_bytes,psi_some_avg10,psi_full_avg10' > "$output_dir/telemetry.csv"

pids=''
worker=1
while [ "$worker" -le "$workers" ]; do
    "$binary" memory "$per_worker_mib" "$rounds" > "$output_dir/worker-$worker.txt" 2>&1 &
    pids="$pids $!"
    worker=$((worker + 1))
done

while :; do
    alive=0
    for pid in $pids; do
        if kill -0 "$pid" 2>/dev/null; then
            alive=1
            break
        fi
    done

    epoch="$(date +%s)"
    mem_available="$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)"
    swap_free="$(awk '/^SwapFree:/ { print $2 }' /proc/meminfo)"
    zram_used="$(awk '{ print $3 }' /sys/block/zram0/mm_stat 2>/dev/null || echo 0)"
    psi_some="$(awk '/^some / { for (i = 1; i <= NF; i++) if ($i ~ /^avg10=/) { sub(/^avg10=/, "", $i); print $i } }' /proc/pressure/memory 2>/dev/null || echo 0)"
    psi_full="$(awk '/^full / { for (i = 1; i <= NF; i++) if ($i ~ /^avg10=/) { sub(/^avg10=/, "", $i); print $i } }' /proc/pressure/memory 2>/dev/null || echo 0)"
    printf '%s,%s,%s,%s,%s,%s\n' "$epoch" "$mem_available" "$swap_free" "$zram_used" "$psi_some" "$psi_full" >> "$output_dir/telemetry.csv"

    [ "$alive" -eq 1 ] || break
    sleep 1
done

status=0
for pid in $pids; do
    if ! wait "$pid"; then
        status=1
    fi
done

snapshot "$output_dir/after.txt"
dmesg > "$output_dir/dmesg-after.txt" 2>/dev/null || true

{
    echo "per_worker_mib=$per_worker_mib"
    echo "workers=$workers"
    echo "total_working_set_mib=$((per_worker_mib * workers))"
    echo "rounds=$rounds"
    echo "status=$status"
    for result in "$output_dir"/worker-*.txt; do
        cat "$result"
    done
} > "$output_dir/result.txt"

exit "$status"
