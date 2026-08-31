param(
    [Parameter(Mandatory = $true)]
    [string] $AdbPath,

    [Parameter(Mandatory = $true)]
    [string] $MagiskBootPath,

    [Parameter(Mandatory = $true)]
    [string] $StockBootImage,

    [Parameter(Mandatory = $true)]
    [string] $KernelImage,

    [string] $KernelDtb,

    [Parameter(Mandatory = $true)]
    [string] $OutputBootImage,

    [switch] $KeepRemoteWork
)

$adb = (Resolve-Path -LiteralPath $AdbPath).Path
$magiskBoot = (Resolve-Path -LiteralPath $MagiskBootPath).Path
$stockBoot = (Resolve-Path -LiteralPath $StockBootImage).Path
$kernel = (Resolve-Path -LiteralPath $KernelImage).Path
$kernelDtb = if ($KernelDtb) { (Resolve-Path -LiteralPath $KernelDtb).Path } else { $null }
$output = [IO.Path]::GetFullPath($OutputBootImage)
$remote = '/data/local/tmp/tb-x505l-kernel-repack'
$createdRemote = $false

if ((Get-Item -LiteralPath $stockBoot).Length -ne 67108864) {
    throw 'The tested TB-X505L boot image is exactly 67,108,864 bytes.'
}

try {
    & $adb root
    if ($LASTEXITCODE -ne 0) {
        throw 'adb root failed. Use a ROM/recovery that permits root ADB.'
    }
    Start-Sleep -Seconds 2
    & $adb wait-for-device

    & $adb shell "test ! -e $remote"
    if ($LASTEXITCODE -ne 0) {
        throw "Refusing to reuse existing remote directory: $remote"
    }

    & $adb shell "mkdir $remote"
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not create the remote work directory.'
    }
    $createdRemote = $true

    & $adb push $magiskBoot "$remote/magiskboot"
    & $adb push $stockBoot "$remote/stock-boot.img"
    & $adb push $kernel "$remote/Image"
    if ($LASTEXITCODE -ne 0) {
        throw 'One or more adb push operations failed.'
    }

    & $adb shell "chmod 0755 $remote/magiskboot"
    & $adb shell "cd $remote && ./magiskboot unpack stock-boot.img"
    if ($LASTEXITCODE -ne 0) {
        throw 'MagiskBoot could not unpack the stock boot image.'
    }

    & $adb shell "test -f $remote/kernel_dtb"
    if ($LASTEXITCODE -ne 0) {
        throw 'Expected appended stock DTB was not extracted; refusing to repack.'
    }

    if ($kernelDtb) {
        & $adb push $kernelDtb "$remote/kernel_dtb"
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not replace the extracted kernel DTB.'
        }
        $expectedDtbHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $kernelDtb).Hash.ToLowerInvariant()
        $remoteDtbHash = ((& $adb shell "sha256sum $remote/kernel_dtb").Trim() -split '\s+')[0]
        if ($remoteDtbHash -ne $expectedDtbHash) {
            throw "Kernel DTB transfer verification failed: expected=$expectedDtbHash actual=$remoteDtbHash"
        }
        Write-Output "Replacement kernel_dtb SHA-256: $expectedDtbHash"
    }

    & $adb shell "cp $remote/Image $remote/kernel"
    & $adb shell "cd $remote && ./magiskboot repack stock-boot.img"
    if ($LASTEXITCODE -ne 0) {
        throw 'MagiskBoot repack failed.'
    }

    & $adb shell "test -f $remote/new-boot.img"
    if ($LASTEXITCODE -ne 0) {
        throw 'MagiskBoot did not create new-boot.img.'
    }

    $outputDirectory = Split-Path -Parent $output
    if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    & $adb pull "$remote/new-boot.img" $output
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not pull the repacked boot image.'
    }

    $resultSize = (Get-Item -LiteralPath $output).Length
    $resultHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $output).Hash.ToLowerInvariant()
    Write-Output "Output: $output"
    Write-Output "Bytes: $resultSize"
    Write-Output "SHA-256: $resultHash"
    Write-Output 'The image has only been created. Test it with fastboot boot before flashing.'
}
finally {
    if ($createdRemote -and -not $KeepRemoteWork) {
        $resolved = (& $adb shell "readlink -f $remote" 2>$null).Trim()
        if ($resolved -eq $remote) {
            & $adb shell "rm -rf $remote" | Out-Null
        }
    }
}
