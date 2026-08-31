param(
    [Parameter(Mandatory = $true)]
    [string] $Root,

    [string] $Manifest = 'SHA256SUMS.txt'
)

$rootPath = (Resolve-Path -LiteralPath $Root).Path
$manifestPath = Join-Path $rootPath $Manifest

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Checksum manifest not found: $manifestPath"
}

$checked = 0
$errors = [System.Collections.Generic.List[string]]::new()

foreach ($line in Get-Content -LiteralPath $manifestPath) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') {
        $errors.Add("Malformed manifest line: $line")
        continue
    }

    $expected = $Matches[1].ToLowerInvariant()
    $relative = $Matches[2].Replace('/', [IO.Path]::DirectorySeparatorChar)
    $path = Join-Path $rootPath $relative

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("Missing file: $relative")
        continue
    }

    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        $errors.Add("Hash mismatch: $relative")
    }

    $checked++
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    throw "Release verification failed with $($errors.Count) error(s)."
}

Write-Output "Verified $checked file(s); no checksum mismatches."
