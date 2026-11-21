# PCCAM Virtual Camera

Makes **PCCAM Camera** appear in the camera list of Windows apps
(screen recorders, Zoom, Teams, Discord, browsers) — no OBS needed.

## Install

1. Put `PCCAMVirtualCam.dll`, `PCCAMVirtualCam32.dll`, `register.bat`
   and `unregister.bat` in a folder you will keep (for example
   `C:\PCCAM`). Windows loads the DLLs from this folder every time an
   app uses the camera, so do not move or delete them afterwards.
2. Right-click `register.bat` → **Run as administrator**.
3. Open your recorder/call app and select **PCCAM Camera**.

The 64-bit DLL serves 64-bit apps; the 32-bit DLL serves 32-bit apps.
The register script installs both.

## Use

- Start the **PCCAM receiver** app and connect your phone first — the
  virtual camera only shows a picture while the receiver is running
  and connected. Rotation/mirror set in the receiver apply to the
  virtual camera too.
- While no app is using the camera, nothing is streamed.

## Remove

Right-click `unregister.bat` → **Run as administrator**, then delete
the folder.

## If registration fails

- Make sure you really ran the script as administrator.
- Some antivirus tools block unknown DirectShow filters; allow the
  DLLs and retry.
- Fallback that always works: use OBS — add a Browser Source with
  `http://localhost:18080/stream` in the PCCAM receiver and start
  OBS Virtual Camera.

## About this component

`PCCAMVirtualCam.dll` is a user-mode DirectShow source filter (no
kernel driver). It is built from source in this folder
(`PCCAMCaptureFilter.cpp` + the DirectShow base-classes subset
`streams.cpp/h`), adapted from **UnityCapture** by Bernhard Schelling
(MIT license, see `LICENSE-UnityCapture.txt`), with PCCAM's own device
name ("PCCAM Camera"), class IDs and shared-memory names
(`PCCAMCapture_*`). Frames travel from the receiver to the filter
through that shared-memory block as RGBA images.

Rebuild (llvm-mingw, from this directory): see `build_filter.sh`.
