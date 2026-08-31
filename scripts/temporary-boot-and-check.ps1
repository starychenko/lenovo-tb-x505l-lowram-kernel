param(
    [Parameter(Mandatory = $true)]
    [string] $AdbPath,

    [Parameter(Mandatory = $true)]
    [string] $FastbootPath,

    [Parameter(Mandatory = $true)]
    [string] $BootImage,

    [switch] $AllowDifferentHash
)

$adb = (Resolve-Path -LiteralPath $AdbPath).Path
$fastboot = (Resolve-Path -LiteralPath $FastbootPath).Path
$boot = (Resolve-Path -LiteralPath $BootImage).Path
$expectedHash = '3dabe282b5f82efa5d4e7496835aca8731d6d1ed3975e281adedeba2fdb3b61f'
$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $boot).Hash.ToLowerInvariant()

Write-Output "Boot image SHA-256: $actualHash"
if (-not $AllowDifferentHash -and $actualHash -ne $expectedHash) {
    throw 'The boot image does not match the published r5 hash.'
}

$bootSize = (Get-Item -LiteralPath $boot).Length
if ($bootSize -ne 67108864) {
    throw "Unexpected boot-image size: $bootSize bytes"
}

& $adb devices -l
if ($LASTEXITCODE -ne 0) {
    throw 'adb devices failed.'
}

& $adb reboot bootloader
if ($LASTEXITCODE -ne 0) {
    throw 'Could not reboot the tablet to bootloader.'
}

$fastbootSeen = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $devices = & $fastboot devices
    if ($devices) {
        $fastbootSeen = $true
        Write-Output $devices
        break
    }
    Start-Sleep -Seconds 1
}

if (-not $fastbootSeen) {
    throw 'No fastboot device appeared within 30 seconds.'
}

& $fastboot boot $boot
if ($LASTEXITCODE -ne 0) {
    throw 'fastboot boot failed. The persistent boot partition was not intentionally changed.'
}

$deadline = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $deadline) {
    $state = & $adb get-state 2>$null
    if ($state -eq 'device') {
        $complete = (& $adb shell getprop sys.boot_completed 2>$null).Trim()
        if ($complete -eq '1') {
            Write-Output 'Android completed boot.'
            & $adb shell uname -a
            & $adb shell 'cat /proc/modules | wc -l'
            & $adb shell cat /proc/asound/cards
            & $adb shell ip -brief address show wlan0
            exit 0
        }
    }
    Start-Sleep -Seconds 5
}

throw 'Android did not complete boot within five minutes.'
