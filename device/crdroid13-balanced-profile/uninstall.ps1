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

$rootIdentity = Invoke-Adb -Arguments @('shell', 'id') -Capture
if ($rootIdentity -notmatch 'uid=0\(root\)') {
    Invoke-Adb -Arguments @('root')
    Invoke-Adb -Arguments @('wait-for-device')
}
Invoke-Adb -Arguments @('remount')

New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path $BackupDirectory "phh-on-boot.before-uninstall.$timestamp.sh"
$workingPath = Join-Path ([System.IO.Path]::GetTempPath()) "tb-x505l-phh-on-boot-uninstall-$timestamp.sh"

try {
    Invoke-Adb -Arguments @('pull', '/system/bin/phh-on-boot.sh', $backupPath)
    $text = [System.IO.File]::ReadAllText($backupPath)
    $pattern = '(?ms)^# BEGIN TB-X505L (?:r6 )?balanced profile\r?\n.*?^# END TB-X505L (?:r6 )?balanced profile\r?\n?'
    $updated = [System.Text.RegularExpressions.Regex]::Replace($text, $pattern, '')
    if ($updated -eq $text) {
        Write-Host 'Boot hook marker was not present.'
    } else {
        [System.IO.File]::WriteAllText(
            $workingPath,
            $updated,
            [System.Text.UTF8Encoding]::new($false)
        )
        Invoke-Adb -Arguments @('push', $workingPath, '/system/bin/phh-on-boot.sh')
        Invoke-Adb -Arguments @('shell', 'chmod 0755 /system/bin/phh-on-boot.sh')
    }

    Invoke-Adb -Arguments @('shell', 'rm -f /system/bin/tb-x505l-balanced-profile.sh /data/local/tmp/tb-x505l-balanced-profile.log')

    $markerCount = Invoke-Adb -Arguments @('shell', "grep -Ec '^# BEGIN TB-X505L (r6 )?balanced profile$' /system/bin/phh-on-boot.sh || true") -Capture
    if ($markerCount -ne '0') {
        throw "Boot hook removal failed; remaining marker count is $markerCount"
    }

    Write-Host "Removed. Pre-removal backup: $backupPath"
    Write-Host 'Reboot to return all scheduler and governor values to their ROM defaults.'
} finally {
    Remove-Item -LiteralPath $workingPath -Force -ErrorAction SilentlyContinue
}
