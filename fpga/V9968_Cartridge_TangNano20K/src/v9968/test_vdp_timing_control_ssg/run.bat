rmdir /S /Q work
vlib work
vlog ..\vdp_timing_control_ssg.v
vlog ..\vdp_timing_control_screen_mode.v
vlog tb.sv
vsim -c -t 1ns -do run.do tb
move transcript log.txt
pause
