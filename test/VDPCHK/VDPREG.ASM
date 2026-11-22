; -----------------------------------------------------------------------------
;	VDPREG.ASM -- V9958 / V9968 VDP command register check (MSX-DOS .COM)
;
;	Checks the registers R#32-R#45 left after every VDP command (V9958
;	table 4.7): a command is followed by commands that rewrite only some
;	registers, so the drawing shows the values kept or updated by the first
;	one.  The script is VDPREG.INC (gen_vdpchk.py), the body VDPCHK_MAIN.ASM.
;	The test numbers continue after the last test of VDPCHK.COM.
;
;	Assemble with zma:  zma VDPREG.ASM VDPREG.COM
; -----------------------------------------------------------------------------

		include	"VDPCHK_MAIN.ASM"

msg_banner:
		db		"VDPREG - VDP command register check", 0x0D, 0x0A, "$"

		include	"VDPREG.INC"
program_end::
