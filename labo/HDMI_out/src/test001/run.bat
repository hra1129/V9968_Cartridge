vlib work

rem -- VHDL simulation models
vcom oser10_model.vhd

rem -- VHDL source
vcom ..\hdmi_tx\src\hdmi_tx_gw.vhd
vcom ..\hdmi_tx\src\video_syncgen.vhd

rem -- Verilog simulation models
vlog gowin_rpll_model.v
vlog gowin_rpll2_model.v

rem -- Verilog source
vlog ..\sound\sound.v
vlog ..\tangnano20k_vdp_cartridge.v

rem -- Testbench
vlog tb.sv

vsim -c -t 1ps -do run.do tb
move transcript log.txt
pause
