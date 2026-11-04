# Removes the "NC2R API Server" autostart task created by
# install-autostart-windows.ps1.

$TaskName = "NC2R API Server"
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Removed '$TaskName' autostart task (if it existed)."
