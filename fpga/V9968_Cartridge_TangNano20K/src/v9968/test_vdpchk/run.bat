@echo off
rem  usage: run.bat [+from=N] [+to=N]
rem  Runs test/VDPCHK/vdpchk.hex (built by test/VDPCHK/build.bat) on the VDP RTL.
cd /d "%~dp0"
if not exist work vlib work
if errorlevel 1 exit /b 1
setlocal enabledelayedexpansion
set files=
for %%f in (..\*.v) do set files=!files! %%f
vlog -sv -quiet !files! tb.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ns -do "run -all; quit -f" tb %*
exit /b %errorlevel%
