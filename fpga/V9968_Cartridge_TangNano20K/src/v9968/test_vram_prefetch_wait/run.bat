@echo off
if not exist work (
    vlib work
    if errorlevel 1 exit /b 1
)
vlog -sv ..\..\msx_slot\msx_slot.v ..\vdp_cpu_interface.v ..\vdp_command_cache.v ..\vdp_vram_interface.v tb.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ps -onfinish stop -do "run -all; if {[examine -radix binary sim:/tb_vram_prefetch_wait/test_passed] != 1} {quit -code 1}; quit -code 0" tb_vram_prefetch_wait
exit /b %errorlevel%
