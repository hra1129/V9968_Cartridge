@echo off
setlocal
pushd "%~dp0"
python gen_vdpview.py
if errorlevel 1 goto error
..\..\tool\zma.exe VDPVIEW.ASM VDPVIEW.COM
if errorlevel 1 goto error
popd
exit /b 0
:error
set result=%errorlevel%
popd
exit /b %result%
