#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <pthread.h>
#include <sched.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#ifndef O_DIRECT
#define O_DIRECT 040000
#endif

static volatile uint64_t result_sink;

static uint64_t monotonic_ns(void)
{
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC_RAW, &ts) != 0) {
        perror("clock_gettime");
        exit(2);
    }
    return (uint64_t)ts.tv_sec * UINT64_C(1000000000) + (uint64_t)ts.tv_nsec;
}

static int compare_u64(const void *left, const void *right)
{
    const uint64_t a = *(const uint64_t *)left;
    const uint64_t b = *(const uint64_t *)right;
    return (a > b) - (a < b);
}

static uint64_t percentile_u64(uint64_t *values, size_t count, unsigned percentile)
{
    if (count == 0) {
        return 0;
    }
    size_t index = ((size_t)percentile * count + 99U) / 100U;
    if (index == 0) {
        index = 1;
    }
    if (index > count) {
        index = count;
    }
    return values[index - 1];
}

static void pin_current_thread(int cpu)
{
    if (cpu < 0) {
        return;
    }
    cpu_set_t set;
    CPU_ZERO(&set);
    CPU_SET(cpu, &set);
    if (sched_setaffinity(0, sizeof(set), &set) != 0) {
        fprintf(stderr, "warning=affinity_failed cpu=%d errno=%d\n", cpu, errno);
    }
}

static uint64_t mix_integer(uint64_t value)
{
    value ^= value >> 12;
    value ^= value << 25;
    value ^= value >> 27;
    return value * UINT64_C(2685821657736338717);
}

struct cpu_worker {
    pthread_barrier_t *barrier;
    uint64_t start_ns;
    uint64_t stop_ns;
    uint64_t iterations;
    uint64_t checksum;
    int cpu;
};

static void *cpu_worker_main(void *opaque)
{
    struct cpu_worker *worker = opaque;
    pin_current_thread(worker->cpu);
    pthread_barrier_wait(worker->barrier);
    while (monotonic_ns() < worker->start_ns) {
        sched_yield();
    }

    uint64_t value = UINT64_C(0x9e3779b97f4a7c15) ^ (uint64_t)(worker->cpu + 17);
    uint64_t iterations = 0;
    do {
        for (unsigned i = 0; i < 16384; ++i) {
            value = mix_integer(value + iterations + i);
        }
        iterations += 16384;
    } while (monotonic_ns() < worker->stop_ns);

    worker->iterations = iterations;
    worker->checksum = value;
    return NULL;
}

static int run_cpu(unsigned seconds, unsigned threads)
{
    const long online = sysconf(_SC_NPROCESSORS_ONLN);
    if (seconds == 0 || threads == 0 || threads > 64) {
        fprintf(stderr, "cpu requires seconds>=1 and 1<=threads<=64\n");
        return 2;
    }

    pthread_t *ids = calloc(threads, sizeof(*ids));
    struct cpu_worker *workers = calloc(threads, sizeof(*workers));
    if (!ids || !workers) {
        perror("calloc");
        free(ids);
        free(workers);
        return 2;
    }

    pthread_barrier_t barrier;
    if (pthread_barrier_init(&barrier, NULL, threads + 1) != 0) {
        fprintf(stderr, "pthread_barrier_init failed\n");
        free(ids);
        free(workers);
        return 2;
    }

    const uint64_t start_ns = monotonic_ns() + UINT64_C(100000000);
    const uint64_t stop_ns = start_ns + (uint64_t)seconds * UINT64_C(1000000000);
    for (unsigned i = 0; i < threads; ++i) {
        workers[i].barrier = &barrier;
        workers[i].start_ns = start_ns;
        workers[i].stop_ns = stop_ns;
        workers[i].cpu = online > 0 ? (int)(i % (unsigned long)online) : -1;
        if (pthread_create(&ids[i], NULL, cpu_worker_main, &workers[i]) != 0) {
            fprintf(stderr, "pthread_create failed at worker %u\n", i);
            return 2;
        }
    }

    pthread_barrier_wait(&barrier);
    while (monotonic_ns() < start_ns) {
        sched_yield();
    }
    uint64_t total_iterations = 0;
    uint64_t checksum = 0;
    for (unsigned i = 0; i < threads; ++i) {
        pthread_join(ids[i], NULL);
        total_iterations += workers[i].iterations;
        checksum ^= workers[i].checksum;
    }
    const uint64_t end_ns = monotonic_ns();
    const double elapsed = (double)(end_ns - start_ns) / 1e9;
    result_sink ^= checksum;
    printf("test=cpu threads=%u requested_s=%u elapsed_s=%.6f iterations=%" PRIu64
           " iterations_per_s=%.3f checksum=%" PRIu64 "\n",
           threads, seconds, elapsed, total_iterations,
           (double)total_iterations / elapsed, checksum);

    pthread_barrier_destroy(&barrier);
    free(ids);
    free(workers);
    return 0;
}

static int run_memory(size_t mib, unsigned rounds)
{
    if (mib < 4 || mib > 512 || rounds == 0) {
        fprintf(stderr, "memory requires 4<=MiB<=512 and rounds>=1\n");
        return 2;
    }
    const size_t bytes = mib * 1024U * 1024U;
    uint8_t *source = NULL;
    uint8_t *target = NULL;
    if (posix_memalign((void **)&source, 4096, bytes) != 0 ||
        posix_memalign((void **)&target, 4096, bytes) != 0) {
        fprintf(stderr, "memory allocation failed for %zu MiB buffers\n", mib);
        free(source);
        free(target);
        return 2;
    }
    for (size_t i = 0; i < bytes; ++i) {
        source[i] = (uint8_t)(i * 131U + 17U);
    }
    memset(target, 0, bytes);

    uint64_t start = monotonic_ns();
    for (unsigned round = 0; round < rounds; ++round) {
        memcpy(target, source, bytes);
        source[(size_t)round % bytes] ^= target[(size_t)(round * 4099U) % bytes];
    }
    uint64_t end = monotonic_ns();
    const double copy_seconds = (double)(end - start) / 1e9;

    uint64_t checksum = 0;
    start = monotonic_ns();
    for (unsigned round = 0; round < rounds; ++round) {
        const uint64_t *words = (const uint64_t *)target;
        for (size_t i = 0; i < bytes / sizeof(*words); ++i) {
            checksum += words[i] ^ (uint64_t)round;
        }
    }
    end = monotonic_ns();
    const double read_seconds = (double)(end - start) / 1e9;

    start = monotonic_ns();
    for (unsigned round = 0; round < rounds; ++round) {
        uint64_t *words = (uint64_t *)target;
        const uint64_t value = UINT64_C(0x0101010101010101) * (round + 1U);
        for (size_t i = 0; i < bytes / sizeof(*words); ++i) {
            words[i] = value ^ i;
        }
        checksum ^= words[(size_t)round % (bytes / sizeof(*words))];
    }
    end = monotonic_ns();
    const double write_seconds = (double)(end - start) / 1e9;
    const double transferred_mib = (double)mib * rounds;
    result_sink ^= checksum;

    printf("test=memory size_mib=%zu rounds=%u copy_mib_s=%.3f read_mib_s=%.3f "
           "write_mib_s=%.3f checksum=%" PRIu64 "\n",
           mib, rounds, transferred_mib / copy_seconds,
           transferred_mib / read_seconds, transferred_mib / write_seconds,
           checksum);
    free(source);
    free(target);
    return 0;
}

struct latency_worker {
    int request_fd;
    int response_fd;
    unsigned exchanges;
    int cpu;
};

static int transfer_byte(int fd, void *buffer, bool write_mode)
{
    for (;;) {
        const ssize_t result = write_mode ? write(fd, buffer, 1) : read(fd, buffer, 1);
        if (result == 1) {
            return 0;
        }
        if (result < 0 && errno == EINTR) {
            continue;
        }
        return -1;
    }
}

static void *latency_worker_main(void *opaque)
{
    struct latency_worker *worker = opaque;
    pin_current_thread(worker->cpu);
    unsigned char byte = 0;
    for (unsigned i = 0; i < worker->exchanges; ++i) {
        if (transfer_byte(worker->request_fd, &byte, false) != 0 ||
            transfer_byte(worker->response_fd, &byte, true) != 0) {
            break;
        }
    }
    return NULL;
}

struct load_worker {
    atomic_bool *stop;
    uint64_t checksum;
    int cpu;
};

static void *load_worker_main(void *opaque)
{
    struct load_worker *worker = opaque;
    pin_current_thread(worker->cpu);
    uint64_t value = UINT64_C(0xd1b54a32d192ed03) ^ (uint64_t)(worker->cpu + 1);
    while (!atomic_load_explicit(worker->stop, memory_order_relaxed)) {
        for (unsigned i = 0; i < 4096; ++i) {
            value = mix_integer(value + i);
        }
    }
    worker->checksum = value;
    return NULL;
}

static int run_latency(unsigned samples, unsigned load_threads, bool same_core)
{
    const unsigned warmup = 200;
    const long online = sysconf(_SC_NPROCESSORS_ONLN);
    if (samples < 100 || samples > 1000000 || load_threads > 64) {
        fprintf(stderr, "latency requires 100<=samples<=1000000 and load_threads<=64\n");
        return 2;
    }
    uint64_t *latencies = calloc(samples, sizeof(*latencies));
    pthread_t *load_ids = calloc(load_threads, sizeof(*load_ids));
    struct load_worker *loaders = calloc(load_threads, sizeof(*loaders));
    if (!latencies || (load_threads && (!load_ids || !loaders))) {
        perror("calloc");
        return 2;
    }

    cpu_set_t original_affinity;
    const bool have_original = sched_getaffinity(0, sizeof(original_affinity), &original_affinity) == 0;
    pin_current_thread(0);

    atomic_bool stop_load = false;
    for (unsigned i = 0; i < load_threads; ++i) {
        loaders[i].stop = &stop_load;
        loaders[i].cpu = online > 0 ? (int)(i % (unsigned long)online) : -1;
        if (pthread_create(&load_ids[i], NULL, load_worker_main, &loaders[i]) != 0) {
            fprintf(stderr, "load pthread_create failed at worker %u\n", i);
            return 2;
        }
    }

    int request_pipe[2];
    int response_pipe[2];
    if (pipe(request_pipe) != 0 || pipe(response_pipe) != 0) {
        perror("pipe");
        return 2;
    }
    struct latency_worker worker = {
        .request_fd = request_pipe[0],
        .response_fd = response_pipe[1],
        .exchanges = samples + warmup,
        .cpu = same_core || online < 2 ? 0 : 1,
    };
    pthread_t worker_id;
    if (pthread_create(&worker_id, NULL, latency_worker_main, &worker) != 0) {
        fprintf(stderr, "latency pthread_create failed\n");
        return 2;
    }

    unsigned char byte = 0x5a;
    uint64_t sum = 0;
    for (unsigned i = 0; i < samples + warmup; ++i) {
        const uint64_t start = monotonic_ns();
        if (transfer_byte(request_pipe[1], &byte, true) != 0 ||
            transfer_byte(response_pipe[0], &byte, false) != 0) {
            fprintf(stderr, "pipe exchange failed at sample %u\n", i);
            return 2;
        }
        const uint64_t elapsed = monotonic_ns() - start;
        if (i >= warmup) {
            latencies[i - warmup] = elapsed;
            sum += elapsed;
        }
    }
    pthread_join(worker_id, NULL);
    atomic_store_explicit(&stop_load, true, memory_order_relaxed);
    uint64_t checksum = 0;
    for (unsigned i = 0; i < load_threads; ++i) {
        pthread_join(load_ids[i], NULL);
        checksum ^= loaders[i].checksum;
    }
    if (have_original) {
        sched_setaffinity(0, sizeof(original_affinity), &original_affinity);
    }

    qsort(latencies, samples, sizeof(*latencies), compare_u64);
    result_sink ^= checksum;
    printf("test=latency mode=%s samples=%u load_threads=%u mean_us=%.3f "
           "p50_us=%.3f p95_us=%.3f p99_us=%.3f max_us=%.3f checksum=%" PRIu64 "\n",
           same_core ? "same-core" : "cross-core", samples, load_threads,
           (double)sum / samples / 1000.0,
           (double)percentile_u64(latencies, samples, 50) / 1000.0,
           (double)percentile_u64(latencies, samples, 95) / 1000.0,
           (double)percentile_u64(latencies, samples, 99) / 1000.0,
           (double)latencies[samples - 1] / 1000.0, checksum);

    close(request_pipe[0]);
    close(request_pipe[1]);
    close(response_pipe[0]);
    close(response_pipe[1]);
    free(latencies);
    free(load_ids);
    free(loaders);
    return 0;
}

static int open_io_file(const char *path, bool *direct)
{
    int fd = open(path, O_CREAT | O_TRUNC | O_RDWR | O_CLOEXEC | O_DIRECT | O_DSYNC, 0600);
    if (fd >= 0) {
        *direct = true;
        return fd;
    }
    fd = open(path, O_CREAT | O_TRUNC | O_RDWR | O_CLOEXEC | O_DSYNC, 0600);
    if (fd >= 0) {
        *direct = false;
    }
    return fd;
}

static int full_pio(int fd, void *buffer, size_t bytes, off_t offset, bool write_mode)
{
    size_t completed = 0;
    while (completed < bytes) {
        ssize_t result;
        if (write_mode) {
            result = pwrite(fd, (char *)buffer + completed, bytes - completed, offset + (off_t)completed);
        } else {
            result = pread(fd, (char *)buffer + completed, bytes - completed, offset + (off_t)completed);
        }
        if (result > 0) {
            completed += (size_t)result;
            continue;
        }
        if (result < 0 && errno == EINTR) {
            continue;
        }
        return -1;
    }
    return 0;
}

static void print_io_latency(const char *operation, uint64_t *values, unsigned count, uint64_t sum)
{
    qsort(values, count, sizeof(*values), compare_u64);
    printf("test=io-random operation=%s block_kib=4 operations=%u mean_us=%.3f "
           "p50_us=%.3f p95_us=%.3f p99_us=%.3f max_us=%.3f iops=%.3f\n",
           operation, count, (double)sum / count / 1000.0,
           (double)percentile_u64(values, count, 50) / 1000.0,
           (double)percentile_u64(values, count, 95) / 1000.0,
           (double)percentile_u64(values, count, 99) / 1000.0,
           (double)values[count - 1] / 1000.0,
           1e9 * count / (double)sum);
}

static int run_io(size_t mib, unsigned random_ops, const char *path)
{
    if (mib < 16 || mib > 2048 || random_ops < 100 || random_ops > 100000) {
        fprintf(stderr, "io requires 16<=MiB<=2048 and 100<=random_ops<=100000\n");
        return 2;
    }
    const size_t chunk = 1024U * 1024U;
    const size_t block = 4096U;
    const off_t total_bytes = (off_t)mib * 1024 * 1024;
    void *buffer = NULL;
    uint64_t *latencies = calloc(random_ops, sizeof(*latencies));
    if (posix_memalign(&buffer, 4096, chunk) != 0 || !latencies) {
        fprintf(stderr, "I/O buffer allocation failed\n");
        free(buffer);
        free(latencies);
        return 2;
    }
    for (size_t i = 0; i < chunk; ++i) {
        ((uint8_t *)buffer)[i] = (uint8_t)(i * 29U + 11U);
    }

    bool direct = false;
    int fd = open_io_file(path, &direct);
    if (fd < 0) {
        perror("open I/O test file");
        free(buffer);
        free(latencies);
        return 2;
    }

    uint64_t start = monotonic_ns();
    for (off_t offset = 0; offset < total_bytes; offset += (off_t)chunk) {
        const size_t remaining = (size_t)(total_bytes - offset);
        const size_t amount = remaining < chunk ? remaining : chunk;
        if (full_pio(fd, buffer, amount, offset, true) != 0) {
            perror("sequential write");
            return 2;
        }
    }
    if (fdatasync(fd) != 0) {
        perror("fdatasync");
        return 2;
    }
    uint64_t end = monotonic_ns();
    const double sequential_write = (double)mib / ((double)(end - start) / 1e9);

    start = monotonic_ns();
    uint64_t checksum = 0;
    for (off_t offset = 0; offset < total_bytes; offset += (off_t)chunk) {
        const size_t remaining = (size_t)(total_bytes - offset);
        const size_t amount = remaining < chunk ? remaining : chunk;
        if (full_pio(fd, buffer, amount, offset, false) != 0) {
            perror("sequential read");
            return 2;
        }
        checksum ^= ((uint64_t *)buffer)[0];
    }
    end = monotonic_ns();
    const double sequential_read = (double)mib / ((double)(end - start) / 1e9);
    printf("test=io-sequential size_mib=%zu direct=%u write_mib_s=%.3f read_mib_s=%.3f\n",
           mib, direct ? 1U : 0U, sequential_write, sequential_read);

    const uint64_t block_count = (uint64_t)total_bytes / block;
    uint64_t random_state = UINT64_C(0x243f6a8885a308d3);
    uint64_t sum = 0;
    for (unsigned i = 0; i < random_ops; ++i) {
        random_state = mix_integer(random_state + i);
        const off_t offset = (off_t)(random_state % block_count) * (off_t)block;
        start = monotonic_ns();
        if (full_pio(fd, buffer, block, offset, false) != 0) {
            perror("random read");
            return 2;
        }
        latencies[i] = monotonic_ns() - start;
        sum += latencies[i];
        checksum ^= ((uint64_t *)buffer)[0];
    }
    print_io_latency("read", latencies, random_ops, sum);

    random_state = UINT64_C(0x13198a2e03707344);
    sum = 0;
    for (unsigned i = 0; i < random_ops; ++i) {
        random_state = mix_integer(random_state + i);
        const off_t offset = (off_t)(random_state % block_count) * (off_t)block;
        ((uint64_t *)buffer)[0] = random_state;
        start = monotonic_ns();
        if (full_pio(fd, buffer, block, offset, true) != 0) {
            perror("random write");
            return 2;
        }
        latencies[i] = monotonic_ns() - start;
        sum += latencies[i];
        checksum ^= random_state;
    }
    if (fdatasync(fd) != 0) {
        perror("random fdatasync");
        return 2;
    }
    print_io_latency("write", latencies, random_ops, sum);

    result_sink ^= checksum;
    close(fd);
    unlink(path);
    free(buffer);
    free(latencies);
    return 0;
}

static void usage(const char *program)
{
    fprintf(stderr,
            "Usage:\n"
            "  %s cpu <seconds> <threads>\n"
            "  %s memory <MiB> <rounds>\n"
            "  %s latency <samples> <load-threads> <same|cross>\n"
            "  %s io <MiB> <random-ops> [path]\n",
            program, program, program, program);
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        usage(argv[0]);
        return 2;
    }
    if (strcmp(argv[1], "cpu") == 0 && argc == 4) {
        return run_cpu((unsigned)strtoul(argv[2], NULL, 10),
                       (unsigned)strtoul(argv[3], NULL, 10));
    }
    if (strcmp(argv[1], "memory") == 0 && argc == 4) {
        return run_memory((size_t)strtoull(argv[2], NULL, 10),
                          (unsigned)strtoul(argv[3], NULL, 10));
    }
    if (strcmp(argv[1], "latency") == 0 && argc == 5) {
        const bool same = strcmp(argv[4], "same") == 0;
        if (!same && strcmp(argv[4], "cross") != 0) {
            usage(argv[0]);
            return 2;
        }
        return run_latency((unsigned)strtoul(argv[2], NULL, 10),
                           (unsigned)strtoul(argv[3], NULL, 10), same);
    }
    if (strcmp(argv[1], "io") == 0 && (argc == 4 || argc == 5)) {
        return run_io((size_t)strtoull(argv[2], NULL, 10),
                      (unsigned)strtoul(argv[3], NULL, 10),
                      argc == 5 ? argv[4] : "/data/local/tmp/tbxbench-io.bin");
    }
    usage(argv[0]);
    return 2;
}
