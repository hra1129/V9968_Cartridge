@echo off
cd /d "%~dp0"
if not exist work vlib work
if errorlevel 1 exit /b 1
vlog -sv ..\vdp_sprite_makeup_pixel.v ..\vdp_sprite_select_visible_planes.v ..\vdp_sprite_info_collect.v ..\vdp_sprite_divide_table.v ..\vdp_timing_control_sprite.v tb.sv tb_r23.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ns -onfinish stop -do "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; if {[examine -radix binary sim:/tb/test_passed] != 1} {quit -code 1}; quit -code 0" tb
if errorlevel 1 exit /b 1
vsim -c -t 1ns -onfinish stop -do "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; if {[examine -radix binary sim:/tb_r23/test_passed] != 1} {quit -code 1}; quit -code 0" tb_r23
exit /b %errorlevel%
