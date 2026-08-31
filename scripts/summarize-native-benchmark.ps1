param(
    [Parameter(Mandatory = $true)]
    [string[]] $InputDirectory,

    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$rows = [System.Collections.Generic.List[object]]::new()

function Convert-KeyValueLine {
    param([string] $Line)

    $values = @{}
    foreach ($token in ($Line -split '\s+')) {
        $parts = $token -split '=', 2
        if ($parts.Count -eq 2) {
            $values[$parts[0]] = $parts[1]
        }
    }
    return $values
}

function Get-Median {
    param([double[]] $Values)

    $sorted = @($Values | Sort-Object)
    if ($sorted.Count % 2 -eq 1) {
        return $sorted[[int][Math]::Floor($sorted.Count / 2)]
    }
    return ($sorted[$sorted.Count / 2 - 1] + $sorted[$sorted.Count / 2]) / 2.0
}

foreach ($directoryName in $InputDirectory) {
    $directory = (Resolve-Path -LiteralPath $directoryName).Path
    $resultPath = Join-Path $directory 'native-results.txt'
    $identityPath = Join-Path $directory 'identity.txt'
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
        throw "Missing native-results.txt in $directory"
    }

    $config = Split-Path -Leaf $directory
    $kernel = ''
    if (Test-Path -LiteralPath $identityPath -PathType Leaf) {
        $uname = Get-Content -LiteralPath $identityPath | Where-Object { $_ -like 'uname=*' } | Select-Object -First 1
        if ($uname) {
            $kernel = $uname.Substring(6)
        }
    }

    $iteration = 0
    $scenario = ''
    foreach ($line in (Get-Content -LiteralPath $resultPath)) {
        if ($line -like 'begin *') {
            $context = Convert-KeyValueLine -Line $line
            $iteration = [int]$context.iteration
            $scenario = [string]$context.name
            continue
        }
        if ($line -notlike 'test=*') {
            continue
        }

        $values = Convert-KeyValueLine -Line $line
        $test = [string]$values.test
        if ($test -eq 'io-random') {
            $test = "io-random-$($values.operation)"
        } elseif ($test -in @('cpu', 'memory', 'latency')) {
            $test = $scenario
        }
        $metadata = @(
            'test', 'threads', 'requested_s', 'mode', 'samples', 'load_threads',
            'checksum', 'size_mib', 'rounds', 'direct', 'operation', 'block_kib',
            'operations'
        )
        foreach ($entry in $values.GetEnumerator()) {
            if ($metadata -contains $entry.Key) {
                continue
            }
            $number = 0.0
            if (-not [double]::TryParse(
                [string]$entry.Value,
                [System.Globalization.NumberStyles]::Float,
                $culture,
                [ref]$number
            )) {
                continue
            }
            $rows.Add([pscustomobject]@{
                Config = $config
                Kernel = $kernel
                Iteration = $iteration
                Scenario = $scenario
                Test = $test
                Metric = [string]$entry.Key
                Value = $number
            })
        }
    }
}

if ($rows.Count -eq 0) {
    throw 'No numeric benchmark rows were parsed.'
}

$summaries = [System.Collections.Generic.List[object]]::new()
foreach ($group in ($rows | Group-Object Config, Test, Metric)) {
    $first = $group.Group[0]
    $values = [double[]]@($group.Group.Value)
    $mean = ($values | Measure-Object -Average).Average
    $sumOfSquares = 0.0
    foreach ($value in $values) {
        $sumOfSquares += [Math]::Pow($value - $mean, 2)
    }
    $standardDeviation = if ($values.Count -gt 1) {
        [Math]::Sqrt($sumOfSquares / ($values.Count - 1))
    } else {
        0.0
    }
    $summaries.Add([pscustomobject]@{
        Config = $first.Config
        Kernel = $first.Kernel
        Test = $first.Test
        Metric = $first.Metric
        Samples = $values.Count
        Median = [Math]::Round((Get-Median -Values $values), 3)
        Mean = [Math]::Round($mean, 3)
        Minimum = [Math]::Round(($values | Measure-Object -Minimum).Minimum, 3)
        Maximum = [Math]::Round(($values | Measure-Object -Maximum).Maximum, 3)
        StdDev = [Math]::Round($standardDeviation, 3)
        CvPercent = if ($mean -ne 0) { [Math]::Round(100.0 * $standardDeviation / [Math]::Abs($mean), 2) } else { 0.0 }
        DeltaVsBaselinePercent = $null
    })
}

$baselineConfig = Split-Path -Leaf (Resolve-Path -LiteralPath $InputDirectory[0]).Path
$baseline = @{}
foreach ($summary in ($summaries | Where-Object Config -eq $baselineConfig)) {
    $baseline["$($summary.Test)|$($summary.Metric)"] = $summary.Median
}
foreach ($summary in $summaries) {
    $key = "$($summary.Test)|$($summary.Metric)"
    if ($baseline.ContainsKey($key) -and $baseline[$key] -ne 0) {
        $summary.DeltaVsBaselinePercent = [Math]::Round(100.0 * ($summary.Median / $baseline[$key] - 1.0), 2)
    }
}

$summaries = @($summaries | Sort-Object Test, Metric, Config)
if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts/native-benchmark-summary.csv'
}
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedOutput) -Force | Out-Null
$summaries | Export-Csv -LiteralPath $resolvedOutput -NoTypeInformation -Encoding utf8

Write-Output "Native benchmark summary: $resolvedOutput"
$summaries | Format-Table Config, Test, Metric, Samples, Median, CvPercent, DeltaVsBaselinePercent -AutoSize
