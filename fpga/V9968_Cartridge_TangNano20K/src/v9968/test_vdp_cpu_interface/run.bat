rmdir /S /Q work
vlib work
vlog ..\vdp_cpu_interface.v
vlog tb.sv
vsim -c -t 1ns -do run.do tb
move transcript log.txt
vsim -c -t 1ns -do run.do tb_port1_latch_reset
move transcript log_port1_latch_reset.txt
vsim -c -t 1ns -do run.do tb_sprite_overmap_status
move transcript log_sprite_overmap_status.txt
pause
