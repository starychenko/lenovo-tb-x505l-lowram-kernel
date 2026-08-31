# Roadmap розвитку ядра TB-X505L після r8-c8

Оновлено після постійної кваліфікації `r8-c8-thinlto` на живому Lenovo
TB-X505L 2/32 ГБ. Це робочий backlog, а не обіцянка ввімкнути кожен популярний твік.
Кожна зміна має лишатися окремим комітом, а кандидати мають збиратися
пакетами за підсистемами, щоб можна було знайти причину регресії без нескінченної
серії мікрозбірок.

## Короткий порядок

| Хвиля | Напрям | Очікуваний результат | Ризик |
|---|---|---|---|
| c4 | scheduler і KGSL submission latency | виконано та перевірено | середній |
| c5 | ARM64 hot paths і `mremap` | виконано; широкі MM backport-и відкладено | середній |
| c6 | BFQ v8r10 | додано selectable; default лишився deadline | середній/високий |
| c7 | KGSL power vote, cpuidle/RCU audit | виконано; потрібні cpuidle/RCU fixes уже були в базі | середній |
| c8 | A53 tuning і ThinLTO | виконано, повторено, постійно прошито | високий |
| c9 | soak, battery, suspend/resume, release hardening | остання хвиля | низький/середній |
| optional | WireGuard, exFAT, HID, sound control | нові можливості, не загальна швидкість | різний |

## c4: швидкодія інтерфейсу та планувальника - виконано

Перший рекомендований пакет. Патчі переносяться окремо, але будуються та
перевіряються однією кандидатною хвилею.

1. Додати prerequisite `use load instead of runnable load` для коректнішого
   load balancing.
2. Покращити розподіл задач між ядрами: не намагатися тягнути utilization із
   CPU, де фактично нема мігровної задачі. У сумісному SDM439 donor це
   маленький backport upstream scheduler patch:
   [sched/fair: Improve spreading of utilization](https://github.com/mi-sdm439/android_kernel_xiaomi_sdm439/commit/ec647f6b6216).
3. Провести prerequisite-аудит повної серії `schedutil iowait boost`, а не
   переносити один випадковий commit. Ціль - правильний reset boost після idle
   та коректна реакція на послідовний I/O:
   [cpufreq: schedutil: Fix iowait boost reset](https://github.com/mi-sdm439/android_kernel_xiaomi_sdm439/commit/a8a0542c7b41).
4. Додати KGSL ioctl latency guard: поки GPU ioctl спить на алокації, не
   дозволяти поточному CPU провалюватися в надто глибокий idle:
   [msm: kgsl: Reduce latency while processing ioctls](https://github.com/mi-sdm439/android_kernel_xiaomi_sdm439/commit/aa4e2ce980c8).
5. Перевірити вилучення непотрібного time profiling із KGSL ringbuffer
   submission.
6. Переглянути KGSL workqueue changes: окремий low-priority worker для
   фонових робіт і достатній пріоритет критичного submission worker.

Живий планшет має лише один доступний GPU-рівень 320 МГц. Тому цей етап
оптимізує CPU-side command submission і latency, а не намагається отримати
швидкість від перемикання GPU governor чи невалідованого розгону.

## c5: пам'ять, zRAM і системні hot paths - частково виконано

7. Оновити LZ4 compressor/decompressor до сумісної новішої реалізації. Це
   стосується swap-in/swap-out напряму, бо поточний zRAM працює на LZ4.
8. Вибрати сумісні `zsmalloc` fixes із новішого Android common 4.9.
9. Дослідити workingset/refault на реальному перемиканні NewPipe, Cromite й
   launcher замість оцінювання лише максимальної синтетичної алокації.
10. Додати telemetry для direct reclaim, kswapd, compaction stalls, PSI та
    refaults у наш тестовий harness.
11. Перевірити donor patch із мінімальною межею readahead.
12. Окремим кандидатом перевірити новіший `vmalloc` backport. Патч широкий,
    тому його не можна змішувати з рештою без окремого контрольного boot.
13. Розглянути оптимізації `mremap` та читання `/proc/*/maps`, які можуть
    зменшити накладні витрати Android Runtime і process tooling.
14. Перенести й окремо виміряти оптимізовані ARM64 `memcmp`, `strcmp`,
    `strrchr`, `strlen` та NEON XOR.

ARM64 crypto acceleration вже ввімкнена: AES, SHA1/SHA2, GHASH і CRC32.
Повторно "додавати" її в roadmap немає сенсу.

## c6: eMMC, writeback та I/O latency - BFQ інтегровано

15. Backport BFQ як selectable scheduler, не як default. Його low-latency
    heuristics можуть допомогти під фоновим I/O, але додають CPU overhead і
    можуть зменшувати throughput:
    [офіційна документація BFQ](https://docs.kernel.org/block/bfq-iosched.html).
16. Порівняти на нашій eMMC:
    - deadline;
    - BFQ low-latency;
    - BFQ без device idling;
    - CFQ із сумісним Pixel-style tuning.
17. Знайти джерело нестабільного random write: writeback congestion, `fsync`,
    dirty throttling, thermal state, cache або фоновий Android I/O.
18. Перевірити ext4 writeback/readahead policy для фактичної `/data`.
19. Перевести лише справді некритичні block workqueues на power-efficient
    workqueue.

Підтримка F2FS уже є в ядрі, але `/data` на живому планшеті використовує ext4.
Перехід на F2FS вимагав би форматування, тому це не звичайний kernel update.

## c7: idle, енергоспоживання та suspend - kernel-аудит виконано

20. Перевірити KGSL CPU-latency relaxation після завершення критичної частини
    GPU command path:
    [msm: kgsl: Relax CPU latency requirements to save power](https://github.com/mi-sdm439/android_kernel_xiaomi_sdm439/commit/02bb7dae79f2).
21. Аудит Qualcomm cpuidle/LPM exit-latency fixes.
22. Вибрати RCU/nohz idle backports, які прибирають непотрібні softirq та
    пробудження в idle.
23. Перевірити thermal-zone update після suspend/resume.
24. Виміряти deep sleep Wi-Fi, GPU та відеодекодера.
25. За потреби зробити окрему політику для тривалого дитячого відео: мінімум
    CPU boost без пропусків кадрів NewPipe.

## c8: компіляторний експеримент - прийнято

26. Підготувати окремий ThinLTO candidate.
27. Перевірити LLD і dead-code/data elimination.
28. Спробувати новіший Clang лише з повним набором потрібних compatibility
    patches.
29. Окремо порівняти generic ARM64 і `-mcpu=cortex-a53`.
30. Перевірити `CONFIG_OPTIMIZE_INLINING`.

Ця хвиля може змінити майже весь binary layout, символи й vendor ABI. Вона не
має змішуватися з функціональними scheduler/MM/GPU змінами.

Фінальний варіант використовує той самий Android Clang 9.0.8, A53 tuning,
optimized inlining і ThinLTO з GNU gold 1.16. Повтор після повернення на
baseline підтвердив latency-напрям; повний audit усіх vendor-модулів не знайшов
CRC drift чи missing symbols. LLD і новіший Clang не ввійшли в c8.

## c9: фінальна стабілізація

1. Кілька днів звичайного дитячого сценарію з NewPipe, браузером і sleep/wake.
2. Виміряти unplugged battery та deep-sleep residency без зміни governor.
3. Повторити suspend/resume, Wi-Fi/video і заряджання після тривалого idle.
4. Перевірити recovery/rollback і релізні checksum-и з чистого завантаження.
5. Лише після цього вирішити, чи c8 можна позначати stable.

## Додаткові можливості

31. WireGuard у ядрі.
32. Сучасніший exFAT для зовнішніх носіїв.
33. Додаткові USB/gamepad/HID драйвери.
34. Sound control із консервативними межами gain для захисту динаміків.
35. Розширена KCAL-конфігурація.
36. Окреме debug-ядро з додатковим tracing, яке не використовується як
    production kernel.
37. Async probe для компонентів, де це безпечно і справді скорочує boot.

## Свідомо не робимо

- GPU overclock: speed-bin живого чипа має лише валідовані 320 МГц.
- CPU overclock або undervolt без достовірних таблиць PMIC та тривалих тестів.
- `dynamic fsync` або вимкнення `fsync`: ризик втрати й пошкодження даних.
- 300/1000 Hz: 300 Hz уже перевіряли, результат був гіршим за 100 Hz.
- Повна заміна EAS/WALT на випадковий custom scheduler.
- `NONTASK_CAPACITY`: уже дав змішаний результат.
- zRAM writeback на стару eMMC без підтвердженої потреби: це додає записи та
  зношування накопичувача.
- Накопичення десятків "твиків" без окремих комітів і розуміння, який із них
  змінив результат.

## Правило приймання змін

Кожна хвиля має пройти:

1. збірку з чистого output directory;
2. config і `Module.symvers` audit;
3. temporary boot;
4. production hardware validator;
5. короткий subsystem-specific тест;
6. memory-pressure smoke;
7. лише після цього permanent flash і release candidate.

Не потрібно щоразу ганяти великий повторний benchmark усього планшета.
Тест має навантажувати саме змінену підсистему, а повний smoke потрібен для
пошуку регресій.
