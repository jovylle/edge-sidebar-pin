@echo off
if "%~1"=="" (
    call "%~dp0_Run.cmd" -Wizard %*
) else (
    call "%~dp0_Run.cmd" %*
)
exit /b %ERRORLEVEL%
