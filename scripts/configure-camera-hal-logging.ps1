[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $AdbPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('quiet', 'diagnostic')]
    [string] $Mode,

    [string] $Serial
)

$adb = (Resolve-Path -LiteralPath $AdbPath).Path
$adbTarget = @()
if ($Serial) {
    $adbTarget = @('-s', $Serial)
}

$quietProfile = [ordered]@{
    'persist.vendor.camera.global.debug'    = '1'
    'persist.vendor.camera.sensor.debug'    = '0'
    'persist.vendor.camera.iface.logs'      = '0'
    'persist.vendor.camera.isp.debug'       = '0'
    'persist.vendor.camera.imglib.logs'     = '0'
    'persist.vendor.camera.stats.debug'     = '0'
    'persist.vendor.camera.stats.af.debug'  = '0'
    'persist.vendor.camera.stats.aec.debug' = '0'
    'persist.vendor.camera.hal.debug'       = '0'
    'persist.vendor.camera.mci.debug'       = '0'
}

# These are the numeric defaults used by the matching Qualcomm camera logging
# implementation.  Setting them explicitly restores useful error/warning
# diagnostics without depending on deletion support for persistent properties.
$diagnosticProfile = [ordered]@{
    'persist.vendor.camera.global.debug'    = '1'
    'persist.vendor.camera.sensor.debug'    = '1'
    'persist.vendor.camera.iface.logs'      = '2'
    'persist.vendor.camera.isp.debug'       = '1'
    'persist.vendor.camera.imglib.logs'     = '2'
    'persist.vendor.camera.stats.debug'     = '1'
    'persist.vendor.camera.stats.af.debug'  = '1'
    'persist.vendor.camera.stats.aec.debug' = '1'
    'persist.vendor.camera.hal.debug'       = '1'
    'persist.vendor.camera.mci.debug'       = '1'
}

$profile = if ($Mode -eq 'quiet') { $quietProfile } else { $diagnosticProfile }

function Get-RemotePid {
    param([Parameter(Mandatory = $true)][string] $ProcessName)

    return (& $adb @adbTarget shell pidof $ProcessName 2>$null).Trim()
}

function Wait-ForNewRemotePid {
    param(
        [Parameter(Mandatory = $true)][string] $ProcessName,
        [Parameter(Mandatory = $true)][string] $PreviousPid
    )

    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        $currentPid = Get-RemotePid -ProcessName $ProcessName
        if ($currentPid -and $currentPid -ne $PreviousPid) {
            return $currentPid
        }
        Start-Sleep -Seconds 1
    }

    throw "Timed out waiting for $ProcessName to restart."
}

& $adb devices -l
if ($LASTEXITCODE -ne 0) {
    throw 'adb devices failed.'
}

& $adb @adbTarget get-state
if ($LASTEXITCODE -ne 0) {
    throw 'The selected ADB target is not ready.'
}

& $adb @adbTarget root
if ($LASTEXITCODE -ne 0) {
    throw 'adb root failed. This helper requires a ROM that permits root ADB.'
}
& $adb @adbTarget wait-for-device

$fingerprint = (& $adb @adbTarget shell getprop ro.vendor.build.fingerprint).Trim()
if ($fingerprint -notlike 'Lenovo/TB-X505L/*') {
    throw "Refusing unsupported vendor fingerprint: $fingerprint"
}

$providerProcess = 'android.hardware.camera.provider@2.4-service'
$providerService = 'vendor.camera-provider-2-4'
$cameraServerProcess = 'cameraserver'
$providerPidBefore = Get-RemotePid -ProcessName $providerProcess
$cameraServerPidBefore = Get-RemotePid -ProcessName $cameraServerProcess

if (-not $providerPidBefore -or -not $cameraServerPidBefore) {
    throw 'The expected TB-X505L camera services are not running.'
}

Write-Output "Applying persistent camera logging profile: $Mode"
foreach ($entry in $profile.GetEnumerator()) {
    $before = (& $adb @adbTarget shell getprop $entry.Key).Trim()
    & $adb @adbTarget shell setprop $entry.Key $entry.Value
    if ($LASTEXITCODE -ne 0) {
        throw "Could not set $($entry.Key)."
    }

    $after = (& $adb @adbTarget shell getprop $entry.Key).Trim()
    if ($after -ne $entry.Value) {
        throw "Property verification failed for $($entry.Key): '$after'."
    }

    Write-Output "$($entry.Key): '$before' -> '$after'"
}

& $adb @adbTarget shell setprop ctl.restart $providerService
if ($LASTEXITCODE -ne 0) {
    throw 'Could not restart the camera provider.'
}
$providerPidAfter = Wait-ForNewRemotePid -ProcessName $providerProcess `
    -PreviousPid $providerPidBefore

& $adb @adbTarget shell setprop ctl.restart $cameraServerProcess
if ($LASTEXITCODE -ne 0) {
    throw 'Could not restart cameraserver.'
}
$cameraServerPidAfter = Wait-ForNewRemotePid -ProcessName $cameraServerProcess `
    -PreviousPid $cameraServerPidBefore

Start-Sleep -Seconds 2
$cameraDump = & $adb @adbTarget shell dumpsys media.camera
if ($LASTEXITCODE -ne 0) {
    throw 'dumpsys media.camera failed after restarting the services.'
}
$cameraDumpText = $cameraDump -join "`n"

if (($cameraDumpText -notmatch 'Device 0 maps to "0"') -or
    ($cameraDumpText -notmatch 'Device 1 maps to "1"')) {
    throw 'Both expected camera IDs were not enumerated after the change.'
}

Write-Output "camera-provider PID: $providerPidBefore -> $providerPidAfter"
Write-Output "cameraserver PID: $cameraServerPidBefore -> $cameraServerPidAfter"
Write-Output 'Camera IDs 0 and 1 are present.'
Write-Output 'The properties persist across reboots. Use -Mode diagnostic to restore diagnostic levels.'
