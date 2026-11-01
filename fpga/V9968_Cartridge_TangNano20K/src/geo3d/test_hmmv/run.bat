@echo off
cd /d "%~dp0"
if not exist work (
    vlib work
    if errorlevel 1 exit /b 1
)
for %%f in (..\..\v9968\*.v) do (
    vlog -sv "%%f"
    if errorlevel 1 exit /b 1
)
vlog -sv ..\geo3d_core.v ..\geo3d_engine.v ..\geo3d_bus.v tb.sv tb_vdp_modes.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ps -onfinish stop -do "run -all; if {[examine -radix binary sim:/tb_geo3d_hmmv/test_passed] != 1} {quit -code 1}; quit -code 0" tb_geo3d_hmmv
if errorlevel 1 exit /b 1
vsim -c -t 1ps -onfinish stop -do "run -all; if {[examine -radix binary sim:/tb_geo3d_vdp_modes/test_passed] != 1} {quit -code 1}; quit -code 0" tb_geo3d_vdp_modes
exit /b %errorlevel%
