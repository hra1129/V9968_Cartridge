@echo off
cd /d "%~dp0"
if exist work rmdir /S /Q work
vlib work
if errorlevel 1 exit /b 1
vlog -sv ..\vdp_timing_control_ssg.v ..\vdp_timing_control_screen_mode.v tb.sv
if errorlevel 1 exit /b 1
rem Waveform bench (no self check)
vsim -c -t 1ns -l log.txt -do run.do tb
if errorlevel 1 exit /b 1
rem Self-checking benches: pass only when the PASS line is printed
call :check tb_scroll_group_alignment
if errorlevel 1 exit /b 1
call :check tb_scroll_midline
if errorlevel 1 exit /b 1
echo ALL PASS
exit /b 0

:check
vsim -c -t 1ns -l log_%1.txt -do "run -all; quit -f" %1
type log_%1.txt >> log.txt
findstr /B /C:"# PASS:" log_%1.txt > nul
set result=%errorlevel%
del log_%1.txt
if not "%result%"=="0" echo FAIL: %1
exit /b %result%