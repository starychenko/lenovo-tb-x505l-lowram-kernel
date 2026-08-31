param(
    [Parameter(Mandatory = $true)]
    [string] $AdbPath,

    [string] $OutputDirectory,

    [ValidateRange(3, 30)]
    [int] $Iterations = 10,

    [ValidateRange(1, 10)]
    [int] $JankIterations = 3
)

$adb = (Resolve-Path -LiteralPath $AdbPath).Path

if (-not $OutputDirectory) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) "artifacts/ui-benchmark-$stamp"
}

$output = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $output -Force | Out-Null

$targets = @(
    [pscustomobject]@{
        Name = 'NewPipe'
        Package = 'org.schabi.newpipe'
        Component = 'org.schabi.newpipe/.MainActivity'
    },
    [pscustomobject]@{
        Name = 'Cromite'
        Package = 'org.cromite.cromite'
        Component = 'org.cromite.cromite/com.google.android.apps.chrome.Main'
    }
)

function Get-Percentile {
    param(
        [double[]] $Values,
        [double] $Percentile
    )

    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 0) {
        return $null
    }

    $index = [Math]::Ceiling(($Percentile / 100.0) * $sorted.Count) - 1
    $index = [Math]::Max(0, [Math]::Min($sorted.Count - 1, $index))
    return $sorted[$index]
}

& $adb devices -l
if ($LASTEXITCODE -ne 0) {
    throw 'adb devices failed.'
}

& $adb wait-for-device
if ($LASTEXITCODE -ne 0) {
    throw 'The tablet is not available through adb.'
}

& $adb shell input keyevent WAKEUP | Out-Null
& $adb shell wm dismiss-keyguard | Out-Null

$identity = @(
    "captured_utc=$([DateTime]::UtcNow.ToString('o'))"
    "iterations=$Iterations"
    "jank_iterations=$JankIterations"
    "uname=$((& $adb shell uname -a).Trim())"
    "fingerprint=$((& $adb shell getprop ro.build.fingerprint).Trim())"
    "bootimage_fingerprint=$((& $adb shell getprop ro.bootimage.build.fingerprint).Trim())"
    "sched_schedstats=$((& $adb shell cat /proc/sys/kernel/sched_schedstats).Trim())"
    "io_scheduler=$((& $adb shell cat /sys/block/mmcblk0/queue/scheduler).Trim())"
    "cpu_governor=$((& $adb shell cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor).Trim())"
    "top_app_boost=$((& $adb shell cat /dev/stune/top-app/schedtune.boost).Trim())"
    "top_app_prefer_idle=$((& $adb shell cat /dev/stune/top-app/schedtune.prefer_idle).Trim())"
    "foreground_boost=$((& $adb shell cat /dev/stune/foreground/schedtune.boost).Trim())"
    "foreground_prefer_idle=$((& $adb shell cat /dev/stune/foreground/schedtune.prefer_idle).Trim())"
    "schedutil_hispeed_freq=$((& $adb shell cat /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq).Trim())"
    "schedutil_hispeed_load=$((& $adb shell cat /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load).Trim())"
    "schedutil_up_rate_limit_us=$((& $adb shell cat /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us).Trim())"
    "schedutil_down_rate_limit_us=$((& $adb shell cat /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us).Trim())"
)
[System.IO.File]::WriteAllLines((Join-Path $output 'identity.txt'), $identity, [System.Text.UTF8Encoding]::new($false))

# Prime dex/page-cache state once. Timed runs still force-stop each process,
# so the measurement is repeatable cold-process startup rather than first boot.
foreach ($target in $targets) {
    & $adb shell am force-stop $target.Package | Out-Null
    & $adb shell am start -W -n $target.Component | Out-Null
    Start-Sleep -Milliseconds 800
}

$rows = [System.Collections.Generic.List[object]]::new()
for ($iteration = 1; $iteration -le $Iterations; $iteration++) {
    foreach ($target in $targets) {
        & $adb shell am force-stop $target.Package | Out-Null
        & $adb shell input keyevent HOME | Out-Null
        Start-Sleep -Milliseconds 700

        $raw = @(& $adb shell am start -W -n $target.Component)
        if ($LASTEXITCODE -ne 0) {
            throw "Launch failed for $($target.Name), iteration $iteration."
        }

        $totalLine = $raw | Where-Object { $_ -match '^TotalTime:\s*(\d+)' } | Select-Object -First 1
        $waitLine = $raw | Where-Object { $_ -match '^WaitTime:\s*(\d+)' } | Select-Object -First 1
        $stateLine = $raw | Where-Object { $_ -match '^LaunchState:\s*(.+)' } | Select-Object -First 1
        if (-not $totalLine -or -not $waitLine) {
            throw "Could not parse launch timing for $($target.Name), iteration $iteration."
        }

        $null = $totalLine -match '^TotalTime:\s*(\d+)'
        $totalTime = [int] $Matches[1]
        $null = $waitLine -match '^WaitTime:\s*(\d+)'
        $waitTime = [int] $Matches[1]
        $launchState = ''
        if ($stateLine -and $stateLine -match '^LaunchState:\s*(.+)') {
            $launchState = $Matches[1].Trim()
        }

        $rows.Add([pscustomobject]@{
            Iteration = $iteration
            Target = $target.Name
            Package = $target.Package
            LaunchState = $launchState
            TotalTimeMs = $totalTime
            WaitTimeMs = $waitTime
        })

        Start-Sleep -Milliseconds 900
    }
}

$rows | Export-Csv -LiteralPath (Join-Path $output 'launch-times.csv') -NoTypeInformation -Encoding utf8

$summary = foreach ($target in $targets) {
    $times = @($rows | Where-Object Target -eq $target.Name | ForEach-Object { [double] $_.TotalTimeMs })
    [pscustomobject]@{
        Target = $target.Name
        Samples = $times.Count
        MinimumMs = [int] (($times | Measure-Object -Minimum).Minimum)
        MedianMs = [int] (Get-Percentile -Values $times -Percentile 50)
        P90Ms = [int] (Get-Percentile -Values $times -Percentile 90)
        MaximumMs = [int] (($times | Measure-Object -Maximum).Maximum)
        MeanMs = [Math]::Round(($times | Measure-Object -Average).Average, 1)
    }
}

$summary | Export-Csv -LiteralPath (Join-Path $output 'launch-summary.csv') -NoTypeInformation -Encoding utf8

$sizeLine = (& $adb shell wm size | Select-Object -Last 1).Trim()
if ($sizeLine -notmatch '(\d+)x(\d+)') {
    throw "Could not parse display size: $sizeLine"
}
$width = [int] $Matches[1]
$height = [int] $Matches[2]
$x = [int] ($width * 0.5)
$fromY = [int] ($height * 0.75)
$toY = [int] ($height * 0.30)

$jankTargets = @(
    [pscustomobject]@{
        Name = 'Settings'
        Package = 'com.android.settings'
        StartArguments = @('-a', 'android.settings.SETTINGS')
    }
)

$jankRows = [System.Collections.Generic.List[object]]::new()
foreach ($target in $jankTargets) {
    for ($jankIteration = 1; $jankIteration -le $JankIterations; $jankIteration++) {
        & $adb shell am force-stop $target.Package | Out-Null
        & $adb shell am start -W @($target.StartArguments) | Out-Null
        Start-Sleep -Seconds 2

        # Exclude process/activity startup. Only the deterministic bidirectional
        # scroll sequence below belongs in the frame-time sample.
        & $adb shell dumpsys gfxinfo $target.Package reset | Out-Null
        for ($swipe = 0; $swipe -lt 12; $swipe++) {
            & $adb shell input swipe $x $fromY $x $toY 280 | Out-Null
            Start-Sleep -Milliseconds 120
            & $adb shell input swipe $x $toY $x $fromY 280 | Out-Null
            Start-Sleep -Milliseconds 120
        }
        $gfxInfo = @(& $adb shell dumpsys gfxinfo $target.Package)
        [System.IO.File]::WriteAllLines(
            (Join-Path $output ('{0}-gfxinfo-{1:D2}.txt' -f $target.Name.ToLowerInvariant(), $jankIteration)),
            $gfxInfo,
            [System.Text.UTF8Encoding]::new($false)
        )

        $values = @{}
        foreach ($line in $gfxInfo) {
            if ($line -match '^Total frames rendered:\s*(\d+)') { $values.TotalFrames = [int]$Matches[1] }
            elseif ($line -match '^Janky frames:\s*(\d+)\s*\(([\d.]+)%\)') {
                $values.JankyFrames = [int]$Matches[1]
                $values.JankyPercent = [double]$Matches[2]
            }
            elseif ($line -match '^50th percentile:\s*(\d+)ms') { $values.P50Ms = [int]$Matches[1] }
            elseif ($line -match '^90th percentile:\s*(\d+)ms') { $values.P90Ms = [int]$Matches[1] }
            elseif ($line -match '^95th percentile:\s*(\d+)ms') { $values.P95Ms = [int]$Matches[1] }
            elseif ($line -match '^99th percentile:\s*(\d+)ms') { $values.P99Ms = [int]$Matches[1] }
            elseif ($line -match '^Number Missed Vsync:\s*(\d+)') { $values.MissedVsync = [int]$Matches[1] }
        }
        $jankRows.Add([pscustomobject]@{
            Iteration = $jankIteration
            Target = $target.Name
            TotalFrames = $values.TotalFrames
            JankyFrames = $values.JankyFrames
            JankyPercent = $values.JankyPercent
            P50Ms = $values.P50Ms
            P90Ms = $values.P90Ms
            P95Ms = $values.P95Ms
            P99Ms = $values.P99Ms
            MissedVsync = $values.MissedVsync
        })
    }
}

$jankRows | Export-Csv -LiteralPath (Join-Path $output 'jank-runs.csv') -NoTypeInformation -Encoding utf8
$jankSummary = foreach ($target in $jankTargets) {
    $targetRows = @($jankRows | Where-Object Target -eq $target.Name)
    [pscustomobject]@{
        Target = $target.Name
        Samples = $targetRows.Count
        MedianFrames = [int](Get-Percentile -Values @($targetRows.TotalFrames) -Percentile 50)
        MedianJankyPercent = [Math]::Round((Get-Percentile -Values @($targetRows.JankyPercent) -Percentile 50), 2)
        MedianP50Ms = [int](Get-Percentile -Values @($targetRows.P50Ms) -Percentile 50)
        MedianP90Ms = [int](Get-Percentile -Values @($targetRows.P90Ms) -Percentile 50)
        MedianP95Ms = [int](Get-Percentile -Values @($targetRows.P95Ms) -Percentile 50)
        MedianP99Ms = [int](Get-Percentile -Values @($targetRows.P99Ms) -Percentile 50)
        MedianMissedVsync = [int](Get-Percentile -Values @($targetRows.MissedVsync) -Percentile 50)
    }
}
$jankSummary | Export-Csv -LiteralPath (Join-Path $output 'jank-summary.csv') -NoTypeInformation -Encoding utf8

& $adb shell input keyevent HOME | Out-Null

Write-Output "UI benchmark: $output"
$summary | Format-Table -AutoSize
$jankSummary | Format-Table -AutoSize
