param(
    [Parameter(Mandatory = $true)]
    [string] $AdbPath,

    [string] $BinaryPath,

    [string] $OutputDirectory,

    [ValidateRange(1, 10)]
    [int] $Iterations = 3,

    [ValidateRange(3, 60)]
    [int] $CpuSeconds = 8,

    [ValidateRange(16, 512)]
    [int] $IoSizeMiB = 128,

    [ValidateRange(100, 10000)]
    [int] $IoOperations = 1024,

    [ValidateRange(30000, 60000)]
    [int] $CooldownTemperatureMillic = 40000,

    [ValidateRange(0, 600)]
    [int] $CooldownTimeoutSeconds = 180,

    [switch] $KeepWifiOn,

    [switch] $KeepScreenOn
)

$ErrorActionPreference = 'Stop'
$adb = (Resolve-Path -LiteralPath $AdbPath).Path
$repoRoot = Split-Path -Parent $PSScriptRoot
$monitor = Join-Path $PSScriptRoot 'benchmark-monitor.sh'

if (-not $BinaryPath) {
    $BinaryPath = Join-Path $repoRoot 'artifacts/tools/tbxbench-aarch64'
}
$binary = (Resolve-Path -LiteralPath $BinaryPath).Path

if (-not (Test-Path -LiteralPath $monitor -PathType Leaf)) {
    throw "Monitor script not found: $monitor"
}
if (-not $OutputDirectory) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputDirectory = Join-Path $repoRoot "artifacts/native-benchmark-$stamp"
}
$output = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $output -Force | Out-Null

function Invoke-Adb {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]] $Arguments)
    & $adb @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "adb command failed: adb $($Arguments -join ' ')"
    }
}

Invoke-Adb devices -l
Invoke-Adb root
Invoke-Adb wait-for-device

$remoteBinary = '/data/local/tmp/tbxbench'
$remoteMonitor = '/data/local/tmp/tbxbench-monitor.sh'
Invoke-Adb push $binary $remoteBinary
Invoke-Adb push $monitor $remoteMonitor
Invoke-Adb shell chmod 0755 $remoteBinary $remoteMonitor

$wifiWasEnabled = ((& $adb shell settings get global wifi_on).Trim() -eq '1')
$powerState = (& $adb shell dumpsys power | Select-String -Pattern 'mWakefulness=' | Select-Object -First 1).Line
$screenWasAwake = $powerState -match 'Awake'

try {
if (-not $KeepWifiOn) {
    Invoke-Adb shell svc wifi disable | Out-Null
}
if (-not $KeepScreenOn) {
    Invoke-Adb shell input keyevent SLEEP | Out-Null
}
Invoke-Adb shell am force-stop com.futuremark.pcmark.android.benchmark | Out-Null

if ($CooldownTimeoutSeconds -gt 0) {
    $deadline = (Get-Date).AddSeconds($CooldownTimeoutSeconds)
    $stableSamples = 0
    $thermalNodes = @(
        '/sys/class/thermal/thermal_zone7/temp'
        '/sys/class/thermal/thermal_zone8/temp'
        '/sys/class/thermal/thermal_zone9/temp'
        '/sys/class/thermal/thermal_zone10/temp'
    )
    do {
        $temperatureLines = @(& $adb shell cat @thermalNodes)
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not read CPU thermal zones.'
        }
        $temperatures = @($temperatureLines | ForEach-Object {
            $parsed = 0
            if ([int]::TryParse($_.Trim(), [ref]$parsed)) { $parsed }
        })
        $maximumTemperature = ($temperatures | Measure-Object -Maximum).Maximum
        if ($maximumTemperature -le $CooldownTemperatureMillic) {
            $stableSamples++
            if ($stableSamples -ge 2) { break }
        } else {
            $stableSamples = 0
        }
        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $deadline)
    if ($stableSamples -lt 2) {
        throw "CPU did not cool to $CooldownTemperatureMillic millicelsius within $CooldownTimeoutSeconds seconds."
    }
}

$identity = @(
    "captured_utc=$([DateTime]::UtcNow.ToString('o'))"
    "iterations=$Iterations"
    "cpu_seconds=$CpuSeconds"
    "io_size_mib=$IoSizeMiB"
    "io_operations=$IoOperations"
    "cooldown_temperature_millic=$CooldownTemperatureMillic"
    "wifi_during_test=$(if ($KeepWifiOn) { 'unchanged' } else { 'disabled' })"
    "screen_during_test=$(if ($KeepScreenOn) { 'unchanged' } else { 'off' })"
    "binary_sha256=$((Get-FileHash -Algorithm SHA256 -LiteralPath $binary).Hash.ToLowerInvariant())"
    "uname=$((Invoke-Adb shell uname '-a' | Out-String).Trim())"
    "fingerprint=$((Invoke-Adb shell getprop ro.build.fingerprint | Out-String).Trim())"
    "io_scheduler=$((Invoke-Adb shell cat /sys/block/mmcblk0/queue/scheduler | Out-String).Trim())"
    "cpu_governor=$((Invoke-Adb shell cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor | Out-String).Trim())"
    "cpu_available_frequencies=$((Invoke-Adb shell cat /sys/devices/system/cpu/cpufreq/policy0/scaling_available_frequencies | Out-String).Trim())"
    "zram_algorithm=$((Invoke-Adb shell cat /sys/block/zram0/comp_algorithm | Out-String).Trim())"
)
[System.IO.File]::WriteAllLines((Join-Path $output 'identity.txt'), $identity, [System.Text.UTF8Encoding]::new($false))

$thermalMap = Invoke-Adb shell 'for z in /sys/class/thermal/thermal_zone*; do printf "%s," "$(basename "$z")"; cat "$z/type" 2>/dev/null; done'
[System.IO.File]::WriteAllLines((Join-Path $output 'thermal-zones.txt'), @($thermalMap), [System.Text.UTF8Encoding]::new($false))

$rawResultPath = Join-Path $output 'native-results.txt'
$resultLines = [System.Collections.Generic.List[string]]::new()

function Invoke-MeasuredTest {
    param(
        [string] $Name,
        [int] $Iteration,
        [string[]] $Command
    )

    $label = ('{0:D2}-{1}' -f $Iteration, $Name)
    $remoteTelemetry = "/data/local/tmp/tbxbench-$label.csv"
    $localTelemetry = Join-Path $output "$label-telemetry.csv"
    $resultLines.Add("begin name=$Name iteration=$Iteration captured_utc=$([DateTime]::UtcNow.ToString('o'))")
    $raw = @(& $adb shell sh $remoteMonitor $remoteTelemetry @Command)
    if ($LASTEXITCODE -ne 0) {
        throw "Native benchmark failed: $Name iteration $Iteration"
    }
    foreach ($line in $raw) {
        $resultLines.Add([string]$line)
    }
    $resultLines.Add("end name=$Name iteration=$Iteration")
    Invoke-Adb pull $remoteTelemetry $localTelemetry | Out-Null
    Invoke-Adb shell rm -f $remoteTelemetry
    Start-Sleep -Seconds 3
}

    for ($iteration = 1; $iteration -le $Iterations; $iteration++) {
        Invoke-MeasuredTest -Name 'cpu-1t' -Iteration $iteration -Command @($remoteBinary, 'cpu', "$CpuSeconds", '1')
        Invoke-MeasuredTest -Name 'cpu-4t' -Iteration $iteration -Command @($remoteBinary, 'cpu', "$CpuSeconds", '4')
        Invoke-MeasuredTest -Name 'memory' -Iteration $iteration -Command @($remoteBinary, 'memory', '64', '8')
        Invoke-MeasuredTest -Name 'latency-same-idle' -Iteration $iteration -Command @($remoteBinary, 'latency', '5000', '0', 'same')
        Invoke-MeasuredTest -Name 'latency-cross-idle' -Iteration $iteration -Command @($remoteBinary, 'latency', '5000', '0', 'cross')
        Invoke-MeasuredTest -Name 'latency-same-loaded' -Iteration $iteration -Command @($remoteBinary, 'latency', '5000', '4', 'same')
        Invoke-MeasuredTest -Name 'latency-cross-loaded' -Iteration $iteration -Command @($remoteBinary, 'latency', '5000', '4', 'cross')
    }

    for ($iteration = 1; $iteration -le $Iterations; $iteration++) {
        Invoke-MeasuredTest -Name 'io' -Iteration $iteration -Command @($remoteBinary, 'io', "$IoSizeMiB", "$IoOperations")
    }

    [System.IO.File]::WriteAllLines($rawResultPath, $resultLines, [System.Text.UTF8Encoding]::new($false))
    $kernelLog = Invoke-Adb shell dmesg
    [System.IO.File]::WriteAllLines((Join-Path $output 'dmesg-after.txt'), @($kernelLog), [System.Text.UTF8Encoding]::new($false))
}
finally {
    if (-not $KeepWifiOn -and $wifiWasEnabled) {
        & $adb shell svc wifi enable | Out-Null
    }
    if (-not $KeepScreenOn -and $screenWasAwake) {
        & $adb shell input keyevent WAKEUP | Out-Null
    }
}

Write-Output "Native benchmark: $output"
Get-FileHash -Algorithm SHA256 -LiteralPath $rawResultPath
