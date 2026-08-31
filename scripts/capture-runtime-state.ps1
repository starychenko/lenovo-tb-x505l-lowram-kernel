param(
    [Parameter(Mandatory = $true)]
    [string] $AdbPath,

    [string] $OutputPath
)

$adb = (Resolve-Path -LiteralPath $AdbPath).Path
$collector = Join-Path $PSScriptRoot 'capture-runtime-state.sh'

if (-not (Test-Path -LiteralPath $collector -PathType Leaf)) {
    throw "Collector script not found: $collector"
}

if (-not $OutputPath) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputPath = Join-Path (Split-Path -Parent $PSScriptRoot) "artifacts/runtime-state-$stamp.txt"
}

$output = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $output
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

& $adb devices -l
if ($LASTEXITCODE -ne 0) {
    throw 'adb devices failed.'
}

& $adb root
if ($LASTEXITCODE -ne 0) {
    throw 'adb root failed. Rooted adbd is required for a complete snapshot.'
}

& $adb wait-for-device
if ($LASTEXITCODE -ne 0) {
    throw 'The tablet did not reconnect after adb root.'
}

$remoteCollector = '/data/local/tmp/tb-x505l-capture-runtime-state.sh'
& $adb push $collector $remoteCollector
if ($LASTEXITCODE -ne 0) {
    throw 'Could not copy the collector to the tablet.'
}

& $adb shell chmod 0755 $remoteCollector
if ($LASTEXITCODE -ne 0) {
    throw 'Could not mark the collector executable.'
}

$snapshot = & $adb exec-out sh $remoteCollector
if ($LASTEXITCODE -ne 0) {
    throw 'Runtime-state collection failed.'
}

[System.IO.File]::WriteAllLines($output, $snapshot, [System.Text.UTF8Encoding]::new($false))
Write-Output "Runtime snapshot: $output"
Get-FileHash -Algorithm SHA256 -LiteralPath $output
