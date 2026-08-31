[CmdletBinding()]
param(
    [string]$Adb = 'adb',
    [string]$Serial,
    [string]$BackupDirectory = (Join-Path $PSScriptRoot '..\..\backups\crdroid13-balanced-profile')
)

$ErrorActionPreference = 'Stop'
$BackupDirectory = [System.IO.Path]::GetFullPath($BackupDirectory)

$adbTarget = @()
if ($Serial) {
    $adbTarget = @('-s', $Serial)
}

function Invoke-Adb {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Arguments,
        [switch]$Capture
    )

    if ($Capture) {
        $output = & $Adb @adbTarget @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "adb failed: $($Arguments -join ' ')`n$($output -join "`n")"
        }
        return ($output -join "`n").Trim()
    }

    & $Adb @adbTarget @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed: $($Arguments -join ' ')"
    }
}

$profileSource = Join-Path $PSScriptRoot 'tb-x505l-balanced-profile.sh'
if (-not (Test-Path -LiteralPath $profileSource -PathType Leaf)) {
    throw "Profile script not found: $profileSource"
}

$fingerprint = Invoke-Adb -Arguments @('shell', 'getprop', 'ro.vendor.build.fingerprint') -Capture
if ($fingerprint -notlike 'Lenovo/TB-X505L/*') {
    throw "Refusing unsupported device: $fingerprint"
}

$rootIdentity = Invoke-Adb -Arguments @('shell', 'id') -Capture
if ($rootIdentity -notmatch 'uid=0\(root\)') {
    Invoke-Adb -Arguments @('root')
    Invoke-Adb -Arguments @('wait-for-device')
    $rootIdentity = Invoke-Adb -Arguments @('shell', 'id') -Capture
    if ($rootIdentity -notmatch 'uid=0\(root\)') {
        throw 'A root ADB shell is required to modify the PHH GSI overlay.'
    }
}

Invoke-Adb -Arguments @('remount')

$mountInfo = Invoke-Adb -Arguments @('shell', 'cat /proc/mounts | grep '' /system '' | head -n 1') -Capture
if ($mountInfo -notmatch '^overlay\s+/system\s+overlay\s+rw,') {
    throw "Expected a writable PHH overlay for /system, got:`n$mountInfo"
}

New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path $BackupDirectory "phh-on-boot.$timestamp.sh"
$workingPath = Join-Path ([System.IO.Path]::GetTempPath()) "tb-x505l-phh-on-boot-$timestamp.sh"

try {
    Invoke-Adb -Arguments @('pull', '/system/bin/phh-on-boot.sh', $backupPath)
    Copy-Item -LiteralPath $backupPath -Destination $workingPath

    $text = [System.IO.File]::ReadAllText($workingPath)
    $originalText = $text
    $legacyBeginMarker = '# BEGIN TB-X505L r6 balanced profile'
    $legacyEndMarker = '# END TB-X505L r6 balanced profile'
    $beginMarker = '# BEGIN TB-X505L balanced profile'
    $endMarker = '# END TB-X505L balanced profile'
    if ($text.Contains($legacyBeginMarker)) {
        $text = $text.Replace($legacyBeginMarker, $beginMarker).Replace($legacyEndMarker, $endMarker)
        Write-Host 'Migrating the legacy r6 marker to the release-neutral marker.'
    }

    $blockPattern = '(?ms)^# BEGIN TB-X505L balanced profile\r?\n.*?^# END TB-X505L balanced profile\r?\n?'
    if ([regex]::IsMatch($text, $blockPattern)) {
        $text = [regex]::Replace($text, $blockPattern, '')
        Write-Host 'Refreshing and repositioning the existing boot hook.'
    }

    $hook = @'
# BEGIN TB-X505L balanced profile
if getprop ro.vendor.build.fingerprint | grep -q '^Lenovo/TB-X505L/'; then
    /system/bin/tb-x505l-balanced-profile.sh apply-staged \
        >/data/local/tmp/tb-x505l-balanced-profile.log 2>&1 &
fi
# END TB-X505L balanced profile
'@

    $anchor = '#Clear looping services'
    $anchorIndex = $text.IndexOf($anchor, [StringComparison]::Ordinal)
    if ($anchorIndex -ge 0) {
        $text = $text.Insert($anchorIndex, $hook.Trim() + "`n")
    } else {
        $text = $text.TrimEnd("`r", "`n") + "`n" + $hook.Trim() + "`n"
    }

    $hookChanged = $text -ne $originalText
    if ($hookChanged) {
        [System.IO.File]::WriteAllText(
            $workingPath,
            $text,
            [System.Text.UTF8Encoding]::new($false)
        )
        Invoke-Adb -Arguments @('push', $workingPath, '/system/bin/phh-on-boot.sh')
    }

    Invoke-Adb -Arguments @('push', $profileSource, '/system/bin/tb-x505l-balanced-profile.sh')
    Invoke-Adb -Arguments @('shell', 'chmod 0755 /system/bin/phh-on-boot.sh /system/bin/tb-x505l-balanced-profile.sh')

    $hookCheck = Invoke-Adb -Arguments @('shell', "grep -c '^# BEGIN TB-X505L balanced profile$' /system/bin/phh-on-boot.sh") -Capture
    if ($hookCheck -ne '1') {
        throw "Boot hook verification failed; marker count is $hookCheck"
    }

    $stagedHookCheck = Invoke-Adb -Arguments @('shell', "grep -c 'tb-x505l-balanced-profile.sh apply-staged' /system/bin/phh-on-boot.sh") -Capture
    if ($stagedHookCheck -ne '1') {
        throw "Staged boot-hook verification failed; match count is $stagedHookCheck"
    }

    $hookLine = [int](Invoke-Adb -Arguments @('shell', "grep -n '^# BEGIN TB-X505L balanced profile$' /system/bin/phh-on-boot.sh | cut -d: -f1") -Capture)
    $cleanupLine = [int](Invoke-Adb -Arguments @('shell', "grep -n '^#Clear looping services$' /system/bin/phh-on-boot.sh | cut -d: -f1") -Capture)
    if ($cleanupLine -gt 0 -and $hookLine -ge $cleanupLine) {
        throw "Boot hook is still after the PHH cleanup delay: hook=$hookLine cleanup=$cleanupLine"
    }

    $legacyHookCheck = Invoke-Adb -Arguments @('shell', "grep -c '^# BEGIN TB-X505L r6 balanced profile$' /system/bin/phh-on-boot.sh || true") -Capture
    if ($legacyHookCheck -ne '0') {
        throw "Legacy boot hook migration failed; marker count is $legacyHookCheck"
    }

    $remoteProfileHash = Invoke-Adb -Arguments @('shell', 'sha256sum /system/bin/tb-x505l-balanced-profile.sh') -Capture
    $localProfileHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $profileSource).Hash.ToLowerInvariant()
    if (($remoteProfileHash -split '\s+')[0] -ne $localProfileHash) {
        throw 'The pushed profile script does not match the local SHA-256.'
    }

    # A previous boot's log can otherwise be mistaken for the new asynchronous
    # staged result immediately after reboot.
    Invoke-Adb -Arguments @('shell', 'rm -f /data/local/tmp/tb-x505l-balanced-profile.log')

    Write-Host "Installed. Original hook backup: $backupPath"
    Write-Host 'The profile activates only on a qualified TB-X505L r6/r7/r8 kernel.'
    Write-Host 'It applies when all nodes appear and again after Android completes boot.'
    Write-Host 'Reboot, then wait for stage=post-boot in /data/local/tmp/tb-x505l-balanced-profile.log.'
} finally {
    Remove-Item -LiteralPath $workingPath -Force -ErrorAction SilentlyContinue
}
