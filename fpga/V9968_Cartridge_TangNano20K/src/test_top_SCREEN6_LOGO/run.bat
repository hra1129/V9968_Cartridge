rmdir /S /Q work
vlib work
vlog MT48LC2M32B2.v
vlog dummy.v
vlog ..\debugger\ip_debugger.v
vlog ..\hdmi_converter\hdmi_converter.v
vlog ..\geo3d\geo3d_bus.v
vlog ..\geo3d\geo3d_core.v
vlog ..\geo3d\geo3d_engine.v
vlog ..\geo3d\geo3d_z80if.v
vlog ..\msx_slot\msx_slot.v
vlog ..\ram\ip_ram.v
vlog ..\sdram\ip_sdram_tangnano20k_c.v
vlog ..\spi_rom\ip_spi_rom.v
vlog ..\system_controller\system_controller.v
vlog ..\tangnano20k_vdp_cartridge.v
vlog ..\v9968\vdp.v
vlog ..\v9968\vdp_color_palette.v
vlog ..\v9968\vdp_color_palette_ram.v
vlog ..\v9968\vdp_command.v
vlog ..\v9968\vdp_command_cache.v
vlog ..\v9968\vdp_cpu_interface.v
vlog ..\v9968\vdp_sprite_divide_table.v
vlog ..\v9968\vdp_sprite_info_collect.v
vlog ..\v9968\vdp_sprite_makeup_pixel.v
vlog ..\v9968\vdp_sprite_select_visible_planes.v
vlog ..\v9968\vdp_timing_control.v
vlog ..\v9968\vdp_timing_control_screen_mode.v
vlog ..\v9968\vdp_timing_control_sprite.v
vlog ..\v9968\vdp_timing_control_ssg.v
vlog ..\v9968\vdp_upscan.v
vlog ..\v9968\vdp_upscan_line_buffer.v
vlog ..\v9968\vdp_video_double_buffer.v
vlog ..\v9968\vdp_video_out.v
vlog ..\v9968\vdp_video_out_bilinear.v
vlog ..\v9968\vdp_video_ram_line_buffer.v
vlog ..\v9968\vdp_vram_interface.v
vlog ..\ws2812_led\ip_ws2812_led.v
vlog tb.sv
vsim -c -t 1ns -gfirst_frame=0 -gnum_frames=8 -do run.do tb
move transcript log.txt
pause
