@echo off
if not exist work (
    vlib work
    if errorlevel 1 exit /b 1
)
vlog -sv ..\ip_i2s_receiver.v tb.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ps -onfinish stop -do "run -all; if {[examine -radix binary sim:/tb_i2s_receiver/test_passed] != 1} {quit -code 1}; quit -code 0" tb_i2s_receiver
exit /b %errorlevel%
