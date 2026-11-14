@echo off
setlocal
pushd "%~dp0"
..\..\tool\zma.exe VRAMSTRS.ASM VRAMSTRS.COM
if errorlevel 1 goto error
popd
exit /b 0
:error
set result=%errorlevel%
popd
exit /b %result%
