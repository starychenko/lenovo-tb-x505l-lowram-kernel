[CmdletBinding()]
param(
    [string] $AdbPath = 'adb',
    [string] $ExpectedSerial
)

$ErrorActionPreference = 'Stop'

function Invoke-Adb {
    & $AdbPath @args
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed: $($args -join ' ')"
    }
}

$serial = (& $AdbPath get-serialno).Trim()
if ($ExpectedSerial -and $serial -ne $ExpectedSerial) {
    throw "Unexpected device '$serial' (expected '$ExpectedSerial')."
}
$model = (& $AdbPath shell getprop ro.product.model).Trim()
$vendorBuild = (& $AdbPath shell getprop ro.vendor.build.display.id).Trim()
if ($model -notmatch 'TB.?X505L' -or $vendorBuild -notmatch 'S001149') {
    throw "Refusing unexpected target: model=$model vendorBuild=$vendorBuild"
}

$originalHookHash = 'b67f17ae57f52ccefb6caec5532c772b85dbbec2cbba92abbd77fb11222d79a8'
$modifiedHookHash = '9adffb001fc7f21d485fc9df1629c996b5ec58ce4118567ef9bf979cb5f4a68b'
$hookAnchor = '[ "$(getprop vold.decrypt)" = "trigger_restart_min_framework" ] && exit 0'
$hookBlock = @'
# TB-X505L has 2 GB RAM and a 1 GB zRAM device. Keep this device-specific so
# the generic GSI is not retuned if it is later reused on another device.
if getprop ro.vendor.build.fingerprint | grep -q '^Lenovo/TB-X505L/'; then
    [ -w /proc/sys/vm/page-cluster ] && echo 0 > /proc/sys/vm/page-cluster
fi
'@
$packages = @(
    'org.lineageos.setupwizard',
    'com.qualcomm.qti.qms.service.telemetry',
    'com.android.printspooler',
    'com.android.bips',
    'com.android.printservice.recommendation',
    'com.android.dreams.basic',
    'com.android.dreams.phototable',
    'com.android.wallpaper.livepicker',
    'org.lineageos.backgrounds',
    'org.lineageos.jelly',
    'com.android.nfc'
)

Invoke-Adb root
Invoke-Adb wait-for-device
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('tb-x505l-tuning-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $currentHook = Join-Path $tempRoot 'phh-on-boot.current.sh'
    $patchedHook = Join-Path $tempRoot 'phh-on-boot.patched.sh'
    Invoke-Adb pull /system/bin/phh-on-boot.sh $currentHook
    $currentHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $currentHook).Hash.ToLowerInvariant()
    $needsHookUpdate = $false

    if ($currentHash -eq $modifiedHookHash) {
        Write-Host 'PHH boot hook already contains the exact TB-X505L block.'
    }
    elseif ($currentHash -eq $originalHookHash) {
        $hookText = [IO.File]::ReadAllText($currentHook)
        if ($hookText.IndexOf($hookAnchor, [StringComparison]::Ordinal) -ne
            $hookText.LastIndexOf($hookAnchor, [StringComparison]::Ordinal)) {
            throw 'The PHH hook anchor is not unique.'
        }
        if (-not $hookText.Contains($hookAnchor)) {
            throw 'The expected PHH hook anchor is missing.'
        }
        $patchedText = $hookText.Replace($hookAnchor, "$hookAnchor`n`n$hookBlock")
        [IO.File]::WriteAllText($patchedHook, $patchedText, [Text.UTF8Encoding]::new($false))
        $patchedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $patchedHook).Hash.ToLowerInvariant()
        if ($patchedHash -ne $modifiedHookHash) {
            throw "Generated hook hash mismatch: expected=$modifiedHookHash actual=$patchedHash"
        }
        $needsHookUpdate = $true
    }
    else {
        throw "Refusing unknown PHH boot hook SHA-256: $currentHash"
    }

    foreach ($package in $packages) {
        Invoke-Adb shell pm disable-user --user 0 $package
    }

    Invoke-Adb shell settings put global window_animation_scale 0.5
    Invoke-Adb shell settings put global transition_animation_scale 0.5
    Invoke-Adb shell settings put global animator_duration_scale 0.5
    Invoke-Adb shell settings put global auto_time 1
    Invoke-Adb shell settings put global auto_time_zone 1
    Invoke-Adb shell cmd alarm set-timezone Europe/Kyiv
    Invoke-Adb shell device_config put activity_manager use_compaction true
    Invoke-Adb shell 'echo 0 > /proc/sys/vm/page-cluster'

    if ($needsHookUpdate) {
        Invoke-Adb remount
        Invoke-Adb push $patchedHook /data/local/tmp/phh-on-boot.tb-x505l.sh
        Invoke-Adb shell 'cp /data/local/tmp/phh-on-boot.tb-x505l.sh /system/bin/phh-on-boot.sh && chown root:shell /system/bin/phh-on-boot.sh && chmod 0755 /system/bin/phh-on-boot.sh && chcon u:object_r:phhsu_exec:s0 /system/bin/phh-on-boot.sh && rm /data/local/tmp/phh-on-boot.tb-x505l.sh'
    }

    $remoteHash = ((& $AdbPath shell sha256sum /system/bin/phh-on-boot.sh) -split '\s+')[0].ToLowerInvariant()
    if ($remoteHash -ne $modifiedHookHash) {
        throw "Boot-hook hash mismatch after apply: expected=$modifiedHookHash actual=$remoteHash"
    }

    foreach ($package in 'org.cromite.cromite','org.schabi.newpipe') {
        if ((& $AdbPath shell pm path $package) -match '^package:') {
            Invoke-Adb shell cmd package compile -m speed -f $package
        }
    }
    Invoke-Adb shell sm fstrim
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
Write-Host 'Applied reversible TB-X505L LineageOS tuning.'
