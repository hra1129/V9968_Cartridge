# test_top_SCREEN5_LMCM — build notes

Purpose: ModelSim bench for the V9968 Cartridge (DUT = `tangnano20k_vdp_cartridge`)
that runs LMCM with NX=1, NY=1 and checks whether TR (S#2 bit7) rises.
Modeled on the author's `test_top_SCREEN5_HMMC` bench, adapted to the current
tree at repo commit `c109272` ("v0.94").

## Files

- `tb.sv` — testbench (details below).
- `dummy.v` — HMMC's stubs + `hdmi_tx` stub appended (see "dummy.v changes").
- `MT48LC2M32B2.v`, `run.do`, `wave.do` — copied verbatim from
  `test_top_SCREEN5_HMMC`.
- `run.bat` — ModelSim script; file list rebuilt from the current
  `tangnano20k_vdp_cartridge.gprj` (see "run.bat").

## tb.sv construction

Copied verbatim from HMMC's tb.sv: license header, signal declarations,
clock generation (`clk14m` toggles with `clk_base = 1e9/85909080` ns),
the `mt48lc2m32b2` instance, and the tasks `write_io`, `write_io_ex`,
`read_io`, `wait_vdp_command` (verified by diff against the HMMC file —
only the DUT instance, the HDMI wire declarations, and everything from
`wait_transfer_ready` onward differ).

Dropped from HMMC: `wait_transfer_ready`, `usagi_transfer`, `lmcm_read`
(scenario-specific), and the HMMC command scenario in the initial block.

Adaptations to the current top module (`src/tangnano20k_vdp_cartridge.v`):
- DUT hookup uses the current port list: `clk, clk14m, slot_* , oe_n,
  dipsw, ws2812_led, button, tmds_clk_p, tmds_d_p, O_sdram_*`.
  The current top has **no** `tmds_clk_n` / `tmds_d_n` ports, so those
  wires/connections from HMMC's tb are removed.
- The top's `mspi_*` (SPI ROM) ports are omitted (unconnected) — the
  bench never touches the config ROM path.
- Ports stay 0x88-based (`dipsw = 0`), as in the other benches.

Scenario (new):
1. Reset + init wait copied from HMMC's initial block
   (`slot_wait` low), then SCREEN5 setup: R#0=0x06, R#1=0x40,
   R#2=0x1F, R#8=0x0A, R#20=0x00, R#21=0x00.
2. VRAM fill copied from HMMC: R#14=0, address 0 write mode, then
   4096 x `write_io(vdp_io0, i & 255)` with `$urandom` delays.
3. Explicit plants via the VRAM port (`plant_vram` task: R#14, address
   low, address high | 0x40, data byte):
   addr 0 <- 8'h12, addr 2565 (0xA05) <- 8'h34, addr 2566 <- 8'h56,
   addr 2567 <- 8'h78.
4. `lmcm_case(sx, sy, nx, ny, expected...)`: writes R#32..R#43 with the
   indirect idiom (R#17=32, then 12 writes to vdp_io3:
   SXl,SXh,SYl,SYh,0,0,0,0,NXl,NXh,NYl,NYh), then R#44=0x00 and
   R#45=0x00 by direct port-1 writes, then R#46=0xA0 (LMCM).
   Drain: per pixel, select S#2 (R#15=2) and poll bit7 — the same
   pattern as HMMC's `lmcm_read`, bound 10000 polls. On timeout it
   prints `[LMCM] TR TIMEOUT (CASE..., pixel ...)`, issues STOP
   (R#46=0x00), and abandons the case instead of `$error`/`$finish`.
   On TR it selects S#7 (R#15=7) and reads the pixel. After the drain
   it calls `wait_vdp_command()` and prints one PASS/FAIL verdict line
   per case with the pixel values.
   Cases:
   - CASE1: SX=10, SY=20, NX=1, NY=1 -> expect {03}
   - CASE2: SX=0,  SY=0,  NX=1, NY=1 -> expect {01}
   - CASE3: SX=10, SY=20, NX=4, NY=1 -> expect {03 04 05 06}
   Ends with `[LMCM] ALL DONE` and `$finish`.

### Deviation from the build request: plant value at addr 0

The request specified addr 0 <- 8'h21 with CASE2 expecting pixel 01.
In GRAPHIC 4 the even-X pixel is the byte's **high** nibble (proven on
real V9958 hardware and in RTL sims: byte 0x12 -> pixel 01, byte 0x34
at SX=10 -> pixel 03), so 8'h21 would return pixel **02** and CASE2
would report a spurious FAIL unrelated to the TR question. The plant
was therefore set to 8'h12 (the same value the earlier LMCMCHK/LMCM2
test programs used at (0,0)), keeping the specified expectation 01.
If 8'h21 was deliberate, change the plant back and set CASE2's
expectation to 8'h02 — one line each.

## dummy.v changes

Copied from HMMC, with two changes:

1. **`Gowin_rPLL2` stub extended with `clkoutd`.** The current top
   connects `.clkoutd ( clk42m )` (CLKOUT/2, geo3d only); HMMC's stub
   predates that port and would fail elaboration. The stub now
   generates `clkoutd` with a toggle FF (init 0). `clkout`/`clkoutp`
   behavior unchanged (pass-through / inverted).
2. **`hdmi_tx` stub appended.** The current top instantiates the VHDL
   `hdmi_tx` (src/hdmi_tx/src/hdmi_tx_gw_patched.vhd) with the
   parameter overrides and port list copied from
   `tangnano20k_vdp_cartridge.v` (u_hdmi_tx, ~line 408). The stub
   declares all those parameters (DEVICE_FAMILY, CLOCK_FREQUENCY,
   ENCODE_MODE, USE_EXTCONTROL, SYNC_POLARITY, SCANMODE,
   PICTUREASPECT, FORMATASPECT, PICTURESCALING, COLORSPACE,
   YCC_DATARANGE, CONTENTTYPE, REPETITION, VIDEO_CODE,
   USE_AUDIO_PACKET, AUDIO_FREQUENCY, PCMFIFO_DEPTH, CATEGORY_CODE)
   and ports (reset, clk, clk_x5, cc_swap, control[3:0], active,
   r_data/g_data/b_data[7:0], hsync, vsync, pcm_fs, pcm_l/pcm_r[23:0],
   data[2:0], data_n[2:0], clock, clock_n), ties all outputs to 0, and
   has no behavior — keeping the bench Verilog-only like its siblings.
   (HMMC's `DVI_TX_Top` stub is kept as-is; nothing in the current
   .gprj file list instantiates it, but it costs nothing.)

## run.bat

Mirrors HMMC's run.bat structure (`rmdir work`, `vlib work`, `vlog`
lines, `vsim -c -t 1ns -do run.do tb`, `move transcript log.txt`,
`pause`), but the file list is the **current** .gprj set: every
Verilog file with enable="1", in .gprj order, excluding
`src/gowin_clkdiv`, `src/gowin_rpll`, `src/gowin_rpll2` (replaced by
dummy.v stubs) and excluding the VHDL hdmi_tx (replaced by the
dummy.v stub) and the .cst/.sdc files. Paths are relative to this
directory (`..\` = src/). HMMC's own run.bat still references the old
`..\th9958\` layout and was not used as the file-list source.

## Validation (Icarus Verilog 12.0, 2026-11-05)

The whole run.bat file list + tb.sv was compiled with
`iverilog -g2012 -s tb` in a scratch copy of the tree, then run with
vvp. No design source was modified (the repo tree is untouched apart
from this new directory; the current `ip_sdram_tangnano20k_c.v`
parses as-is).

- **Compile/elaboration: clean, exit 0, no errors or warnings** —
  the full current top (geo3d, system_controller, spi_rom, hdmi stub,
  extended rPLL2 stub, ip_sdram + Micron model) elaborates.
- **Run: completed** ($finish reached; ~7.55M time units). Output:

  ```
  [test---] Wait initialization
  [test001] Write VRAM
  [LMCM] Plant VRAM bytes
  [LMCM] CASE1 SX=10 SY=20 NX=1 NY=1 PIX=03 EXPECT=03 -> PASS
  [LMCM] CASE2 SX=0 SY=0 NX=1 NY=1 PIX=01 EXPECT=01 -> PASS
  [LMCM] CASE3 SX=10 SY=20 NX=4 NY=1 PIX=03 04 05 06 EXPECT=03 04 05 06 -> PASS
  [LMCM] ALL DONE
  ```

  So at RTL level LMCM 1x1 behaves correctly — consistent with all
  earlier Icarus simulations. The bench's purpose is the ModelSim /
  gate-level (SDF) run, where the FPGA's deterministic TR timeout
  may reproduce.

Scratch-only adaptations (the repo files keep the author's idiom;
these were needed solely because of Icarus limitations):

1. Icarus 12 reports `break` as "not supported", so in the scratch
   copy only, the `forever`+`break` polls in `wait_vdp_command`
   (verbatim HMMC code) and in `lmcm_case` were respelled as
   flag-controlled `while` loops with identical bounds and behavior.
   ModelSim accepts `break`; the shipped tb.sv uses it, matching the
   sibling benches.
2. The fill's `repeat( $urandom(40) )` is copied verbatim from HMMC.
   Icarus treats `$urandom(x)` as the seed form (returns a full-range
   value and rejects a literal seed), so the scratch run substituted
   `$urandom_range(40)`. If ModelSim also treats it as the seed form,
   the fill delay would explode there too — but every author bench
   uses the same line, so its behavior in the author's ModelSim is
   presumably as intended.

## Not exercised by this bench

- The config-ROM / system-controller path (top `mspi_*` ports left
  unconnected; no Enabler or SPI ROM access in the scenario).
- Geo3D (idle; it only receives its clk42m from the rPLL2 stub).
- HDMI output content (stubbed), audio, ws2812 LED, debugger port.
- VR=1 (R#8 bit3) addressing above 64KB: R#8=0x0A comes from HMMC's
  SCREEN5 setup (VR=0), and all plants/cases are below 0x4000, so
  the 14-bit CPU-port truncation under VR=0 cannot affect them —
  same reasoning as the Z80-side tests.
- Display is ON during the cases (R#1=0x40), matching the hardware
  test conditions that failed.
