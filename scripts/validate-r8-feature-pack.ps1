param(
    [Parameter(Mandatory = $true)]
    [string] $AdbPath,

    [string] $OutputPath,

    [switch] $ActiveTests,

    [switch] $ProductionProfile
)

$ErrorActionPreference = 'Stop'
$adb = (Resolve-Path -LiteralPath $AdbPath).Path
$validator = Join-Path $PSScriptRoot 'validate-r8-feature-pack.sh'

if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
    throw "Validator script not found: $validator"
}

if (-not $OutputPath) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputPath = Join-Path (Split-Path -Parent $PSScriptRoot) "artifacts/r8-validation-$stamp.txt"
}

$output = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $output
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$state = (& $adb get-state 2>$null).Trim()
if ($state -ne 'device') {
    throw "Expected one online ADB device, got: $state"
}

& $adb root | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'adb root failed. Rooted adbd is required for kernel validation.'
}
& $adb wait-for-device | Out-Null

$remoteValidator = '/data/local/tmp/tb-x505l-validate-r8-feature-pack.sh'
$mode = if ($ProductionProfile) { 'production' } elseif ($ActiveTests) { 'active' } else { 'read-only' }
$lines = @()
$remoteCreated = $false

try {
    & $adb shell "test ! -e $remoteValidator"
    if ($LASTEXITCODE -ne 0) {
        throw "Refusing to overwrite the existing remote validator: $remoteValidator"
    }

    & $adb push $validator $remoteValidator | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not copy the runtime validator to the tablet.'
    }
    $remoteCreated = $true

    & $adb shell chmod 0755 $remoteValidator | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not mark the runtime validator executable.'
    }

    $lines = @(& $adb exec-out sh $remoteValidator $mode)
    $remoteExitCode = $LASTEXITCODE
    [System.IO.File]::WriteAllLines($output, $lines, [System.Text.UTF8Encoding]::new($false))
    $lines | Write-Output

    if ($remoteExitCode -ne 0 -or -not ($lines -contains 'RESULT=PASS')) {
        throw "Runtime validation failed. Evidence: $output"
    }
}
finally {
    if ($remoteCreated) {
        & $adb shell "rm -f $remoteValidator" | Out-Null
    }
}

Write-Output "Validation evidence: $output"
Get-FileHash -Algorithm SHA256 -LiteralPath $output
