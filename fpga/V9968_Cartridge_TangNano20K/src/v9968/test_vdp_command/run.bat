@echo off
cd /d "%~dp0"
if not exist work vlib work
if errorlevel 1 exit /b 1
vlog -sv ..\vdp_command.v tb.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ns -onfinish stop -do "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; if {[examine -radix binary sim:/tb/test_passed] != 1} {quit -code 1}; quit -code 0" tb
exit /b %errorlevel%
