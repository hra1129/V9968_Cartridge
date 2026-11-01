# Geo3D

v2.0.0
https://github.com/alexmoncks/V9968_Cartridge/tree/main/geo3d

On this cartridge, untextured filled-face spans in SCREEN 8 with LOP=IMP
automatically use the V9968 HMMV write path; no software setting is needed.
Geo3D still emits a LINE, which the VDP converts to a one-row HMMV at command
start. Other screen modes, logical operations, textured faces, wireframe lines,
and spans starting outside SCREEN 8 retain their existing paths. This excludes
the YJK modes even though they share the VDP's G7 mode bit. The VDP command
parameters left after an optimized span retain their LINE values.
If the screen mode changes during an optimized span, the VDP returns to LINE
before processing the next pixel.

Run `test_hmmv\run.bat` with ModelSim on PATH to check LINE compatibility and
VDP screen-mode selection.
