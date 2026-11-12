@echo off
cd /d "%~dp0"
if not exist work vlib work
if errorlevel 1 exit /b 1
vlog -sv ..\vdp_timing_control_screen_mode.v ..\vdp_color_palette_ram.v ..\vdp_color_palette.v tb.sv tb_screen8_mask.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ns -onfinish stop -do "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; if {[examine -radix binary sim:/tb/test_passed] != 1} {quit -code 1}; quit -code 0" tb
if errorlevel 1 exit /b 1
vsim -c -t 1ns -onfinish stop -do "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; if {[examine -radix binary sim:/tb_screen8_mask/test_passed] != 1} {quit -code 1}; quit -code 0" tb_screen8_mask
exit /b %errorlevel%
