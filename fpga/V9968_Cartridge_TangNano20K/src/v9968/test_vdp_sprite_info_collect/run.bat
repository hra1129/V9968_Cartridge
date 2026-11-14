@echo off
cd /d "%~dp0"
if exist work rmdir /S /Q work
vlib work
if errorlevel 1 exit /b 1
vlog -sv ..\vdp_sprite_info_collect.v tb.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ns -l log.txt -do "run -all; quit -f" tb
findstr /B /C:"# PASS:" log.txt > nul
if errorlevel 1 (
	echo FAIL
	exit /b 1
)
echo ALL PASS
exit /b 0
