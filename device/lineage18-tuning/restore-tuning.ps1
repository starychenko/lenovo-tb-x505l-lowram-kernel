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
if ($model -notmatch 'TB.?X505L') {
    throw "Refusing unexpected target: model=$model"
}

$originalHookHash = 'b67f17ae57f52ccefb6caec5532c772b85dbbec2cbba92abbd77fb11222d79a8'
$modifiedHookHash = '9adffb001fc7f21d485fc9df1629c996b5ec58ce4118567ef9bf979cb5f4a68b'
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
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('tb-x505l-restore-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $currentHook = Join-Path $tempRoot 'phh-on-boot.current.sh'
    $restoredHook = Join-Path $tempRoot 'phh-on-boot.restored.sh'
    Invoke-Adb pull /system/bin/phh-on-boot.sh $currentHook
    $currentHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $currentHook).Hash.ToLowerInvariant()
    $needsHookUpdate = $false

    if ($currentHash -eq $originalHookHash) {
        Write-Host 'PHH boot hook is already at the known original hash.'
    }
    elseif ($currentHash -eq $modifiedHookHash) {
        $hookText = [IO.File]::ReadAllText($currentHook)
        $needle = "`n`n$hookBlock"
        if ($hookText.IndexOf($needle, [StringComparison]::Ordinal) -ne
            $hookText.LastIndexOf($needle, [StringComparison]::Ordinal)) {
            throw 'The TB-X505L hook block is not unique.'
        }
        if (-not $hookText.Contains($needle)) {
            throw 'The expected TB-X505L hook block is missing.'
        }
        $restoredText = $hookText.Replace($needle, '')
        [IO.File]::WriteAllText($restoredHook, $restoredText, [Text.UTF8Encoding]::new($false))
        $restoredHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $restoredHook).Hash.ToLowerInvariant()
        if ($restoredHash -ne $originalHookHash) {
            throw "Generated original-hook hash mismatch: expected=$originalHookHash actual=$restoredHash"
        }
        $needsHookUpdate = $true
    }
    else {
        throw "Refusing unknown PHH boot hook SHA-256: $currentHash"
    }

    foreach ($package in $packages) {
        Invoke-Adb shell pm enable --user 0 $package
    }

    Invoke-Adb shell settings put global window_animation_scale 1.0
    Invoke-Adb shell settings put global transition_animation_scale 1.0
    Invoke-Adb shell settings put global animator_duration_scale 1.0
    Invoke-Adb shell device_config delete activity_manager use_compaction
    Invoke-Adb shell 'echo 3 > /proc/sys/vm/page-cluster'

    if ($needsHookUpdate) {
        Invoke-Adb remount
        Invoke-Adb push $restoredHook /data/local/tmp/phh-on-boot.original.sh
        Invoke-Adb shell 'cp /data/local/tmp/phh-on-boot.original.sh /system/bin/phh-on-boot.sh && chown root:shell /system/bin/phh-on-boot.sh && chmod 0755 /system/bin/phh-on-boot.sh && chcon u:object_r:phhsu_exec:s0 /system/bin/phh-on-boot.sh && rm /data/local/tmp/phh-on-boot.original.sh'
    }

    $remoteHash = ((& $AdbPath shell sha256sum /system/bin/phh-on-boot.sh) -split '\s+')[0].ToLowerInvariant()
    if ($remoteHash -ne $originalHookHash) {
        throw "Boot-hook hash mismatch after restore: expected=$originalHookHash actual=$remoteHash"
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
Write-Host 'Restored package states, animation defaults and original PHH hook.'
