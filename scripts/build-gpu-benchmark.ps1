param(
    [string] $NdkRoot = 'C:\GIT\mobile-apps\.tools\android-sdk\ndk\27.1.12297006',
    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot 'benchmarks\gpu\tbx-gpu-bench.c'
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot 'artifacts\tools\tbx-gpu-bench-aarch64'
}

$clang = Join-Path $NdkRoot 'toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android29-clang.cmd'
if (-not (Test-Path -LiteralPath $clang -PathType Leaf)) {
    throw "Android NDK Clang was not found: $clang"
}
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "GPU benchmark source was not found: $source"
}

$output = [System.IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null

& $clang -std=c11 -O3 -fPIE -pie -Wall -Wextra -Werror $source -o $output -lEGL -lGLESv2 -lm
if ($LASTEXITCODE -ne 0) {
    throw "GPU benchmark build failed with exit code $LASTEXITCODE"
}

Get-Item -LiteralPath $output | Select-Object FullName,Length
Get-FileHash -Algorithm SHA256 -LiteralPath $output
