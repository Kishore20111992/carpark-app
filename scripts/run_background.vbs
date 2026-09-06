Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "E:\mainframe-storage-app"
WshShell.Run "cmd /c scripts\run_onprem_windows.bat", 0, False
