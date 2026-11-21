@echo off
REM ============================================================
REM  PCCAM Virtual Camera - unregister
REM  Right-click this file and choose "Run as administrator".
REM  Removes "PCCAM Camera" from the camera list. After this
REM  you can delete the DLL files.
REM ============================================================
setlocal
set "DIR=%~dp0"

echo Unregistering PCCAM Camera (64-bit)...
"%SystemRoot%\System32\regsvr32.exe" /s /u "%DIR%PCCAMVirtualCam.dll"

if exist "%SystemRoot%\SysWOW64\regsvr32.exe" (
  echo Unregistering PCCAM Camera (32-bit)...
  "%SystemRoot%\SysWOW64\regsvr32.exe" /s /u "%DIR%PCCAMVirtualCam32.dll"
)

echo.
echo Done. "PCCAM Camera" has been removed.
echo.
pause
