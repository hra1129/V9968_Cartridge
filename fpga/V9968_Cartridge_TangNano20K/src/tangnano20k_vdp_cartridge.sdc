//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12.02_SP2 (64-bit) 
//Created Time: 2026-04-14 21:33:47

# 入力クロック
create_clock -name clk    -period 37.03704 -waveform {0 18.518} [get_ports {clk}]
create_clock -name clk14m -period 69.84128 -waveform {0 34.921} [get_ports {clk14m}]

# PLL 出力クロック
create_generated_clock -name clk215m  -source [get_ports {clk14m}] -master_clock clk14m -multiply_by 15 [get_nets {clk215m}]
create_generated_clock -name clk85m   -source [get_ports {clk14m}] -master_clock clk14m -multiply_by 6 [get_nets {clk85m}]
# create_generated_clock -name clk85m_n -source [get_ports {clk14m}] -master_clock clk14m -multiply_by 6 -phase 180 [get_nets {clk85m_n}]
create_generated_clock -name clk42m   -source [get_nets {clk85m}] -master_clock clk85m -divide_by 2 [get_nets {clk42m}]

# 非同期クロックグループ宣言 → clk1とclk2間の全パスをタイミング除外
set_clock_groups -asynchronous -group [get_clocks {clk215m}] -group [get_clocks {clk42m}]
set_clock_groups -asynchronous -group [get_clocks {clk}] -group [get_clocks {clk85m}]
