' Launches start-server.bat with no visible window at all (window style 0).
' Used by the "hidden" Task Scheduler autostart mode.
Set objShell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
objShell.Run """" & scriptDir & "\start-server.bat""", 0, False
