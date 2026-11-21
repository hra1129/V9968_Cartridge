@echo off
setlocal
pushd "%~dp0"
if not exist work (
    vlib work
    if errorlevel 1 goto error
)
vlog ..\vdp_cpu_interface.v
if errorlevel 1 goto error
vlog tb.sv
if errorlevel 1 goto error
vsim -c -t 1ns -suppress 2685 -suppress 3722 -onfinish stop -do "run -all; if {[examine -radix binary sim:/tb_line_interrupt/test_passed] != 1} {quit -code 1 -f}; quit -code 0 -f" tb_line_interrupt
if errorlevel 1 goto error
popd
exit /b 0
:error
set result=%errorlevel%
popd
exit /b %result%
