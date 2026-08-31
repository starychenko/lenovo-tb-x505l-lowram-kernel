[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $FirmwareImageDirectory,

    [string] $ManifestPath = (Join-Path $PSScriptRoot '..\firmware\TB-X505L-S001149-critical-sha256.txt')
)

$ErrorActionPreference = 'Stop'
$FirmwareImageDirectory = (Resolve-Path -LiteralPath $FirmwareImageDirectory).Path
$ManifestPath = (Resolve-Path -LiteralPath $ManifestPath).Path

# Accept either the directory that directly contains boot.img/vendor.img or
# the package directory that contains an "image" child directory.
if (-not (Test-Path -LiteralPath (Join-Path $FirmwareImageDirectory 'boot.img') -PathType Leaf)) {
    $imageChild = Join-Path $FirmwareImageDirectory 'image'
    if (Test-Path -LiteralPath (Join-Path $imageChild 'boot.img') -PathType Leaf) {
        $FirmwareImageDirectory = $imageChild
    }
}

$checked = 0
$failures = @()

foreach ($line in Get-Content -LiteralPath $ManifestPath) {
    $line = $line.Trim()
    if (-not $line -or $line.StartsWith('#')) {
        continue
    }

    if ($line -notmatch '^([0-9a-fA-F]{64})\s+\*?(.+)$') {
        throw "Malformed manifest line: $line"
    }

    $expected = $Matches[1].ToLowerInvariant()
    $relativePath = $Matches[2].Trim()
    $path = Join-Path $FirmwareImageDirectory $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures += "MISSING  $relativePath"
        continue
    }

    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        $failures += "BAD HASH $relativePath expected=$expected actual=$actual"
    }
    else {
        Write-Host "OK       $relativePath"
    }
    $checked++
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Firmware verification failed with $($failures.Count) error(s)."
}

Write-Host "Verified $checked critical Lenovo S001149 files."
