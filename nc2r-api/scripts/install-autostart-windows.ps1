# Registers a Windows Task Scheduler task that keeps the NC2R Laravel API
# running: it starts at BOOT (even after a power cut / forced shutdown, with
# nobody logged in) when run as Administrator, otherwise at user logon. The
# task's script (start-server.bat) then restarts the server forever if it dies,
# and Task Scheduler itself restarts the script if that ever fails.
#
# Usage:
#   Right-click PowerShell -> Run as administrator   (recommended: start at boot)
#   .\install-autostart-windows.ps1
#   .\install-autostart-windows.ps1 -Hidden   # (logon mode only) no console window
#
# Remove: .\uninstall-autostart-windows.ps1

param(
    [switch]$Hidden
)

$TaskName = "NC2R API Server"
$ScriptDir = $PSScriptRoot
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$IsAdmin = (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    # S4U: runs whether or not the user is logged in, no password stored, no window.
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Principal = New-ScheduledTaskPrincipal -UserId $identity.Name -LogonType S4U -RunLevel Limited
    $Action = New-ScheduledTaskAction -Execute "cmd.exe" `
        -Argument "/c `"$ScriptDir\start-server.bat`"" -WorkingDirectory $ScriptDir
    $Mode = "at BOOT (no login needed)"
} else {
    $Trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity.Name
    $Principal = New-ScheduledTaskPrincipal -UserId $identity.Name -LogonType Interactive
    if ($Hidden) {
        $Action = New-ScheduledTaskAction -Execute "wscript.exe" `
            -Argument "`"$ScriptDir\start-server-hidden.vbs`""
    } else {
        $Action = New-ScheduledTaskAction -Execute "cmd.exe" `
            -Argument "/c start /min `"`" `"$ScriptDir\start-server.bat`"" `
            -WorkingDirectory $ScriptDir
    }
    $Mode = "at user LOGON (run as Administrator to start at boot instead)"
}

$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -MultipleInstances IgnoreNew `
    -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
        -Principal $Principal -Settings $Settings `
        -Description "Runs and auto-restarts the NC2R Laravel API (php artisan serve)." `
        -ErrorAction Stop | Out-Null
} catch {
    Write-Error "Failed to register the task: $($_.Exception.Message)"
    exit 1
}

Write-Host "Installed '$TaskName' - starts $Mode."
Write-Host "Start it now:  Start-ScheduledTask -TaskName `"$TaskName`""
Write-Host "Restart log:   $ScriptDir\..\storage\logs\server-restarts.log"
