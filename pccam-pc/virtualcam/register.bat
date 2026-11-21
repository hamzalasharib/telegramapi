@echo off
REM ============================================================
REM  PCCAM Virtual Camera - register
REM  Right-click this file and choose "Run as administrator".
REM  After registering, "PCCAM Camera" appears in the camera
REM  list of recorders and call apps. Keep the two DLL files in
REM  this folder - Windows loads them from here. To remove the
REM  camera again, run unregister.bat (also as administrator).
REM ============================================================
setlocal
set "DIR=%~dp0"

echo Registering PCCAM Camera (64-bit)...
"%SystemRoot%\System32\regsvr32.exe" /s "%DIR%PCCAMVirtualCam.dll"
if errorlevel 1 goto fail

if exist "%SystemRoot%\SysWOW64\regsvr32.exe" (
  echo Registering PCCAM Camera (32-bit, for 32-bit apps)...
  "%SystemRoot%\SysWOW64\regsvr32.exe" /s "%DIR%PCCAMVirtualCam32.dll"
  if errorlevel 1 goto fail
)

echo.
echo Done. "PCCAM Camera" is registered.
echo Start the PCCAM receiver app and connect your phone - the picture
echo only flows while the receiver is running and connected.
goto end

:fail
echo.
echo Registration FAILED. Most common reason: not running as
echo administrator. Right-click register.bat and choose
echo "Run as administrator", then try again.

:end
echo.
pause
