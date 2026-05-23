@echo off
REM Internal launcher — use Start.cmd, Pin.cmd, or Restore.cmd.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Edge-Set-SidebarApp.ps1" %*
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
    echo.
    echo Something went wrong ^(exit %EC%^). See the message above.
)
echo.
pause
exit /b %EC%
