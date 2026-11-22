; -----------------------------------------------------------------------------
;	VDPCHK.ASM -- V9958 / V9968 VDP command and VRAM self check (MSX-DOS .COM)
;
;	CPU VRAM access, VDP commands in every screen mode, FG4 and the 4MB VRAM
;	banks.  The script is VDPCHK.INC (gen_vdpchk.py), the body VDPCHK_MAIN.ASM.
;	The registers left after a command are checked by VDPREG.COM.
;
;	Assemble with zma:  zma VDPCHK.ASM VDPCHK.COM
; -----------------------------------------------------------------------------

		include	"VDPCHK_MAIN.ASM"

msg_banner:
		db		"VDPCHK - VDP command / VRAM self check", 0x0D, 0x0A, "$"

		include	"VDPCHK.INC"
program_end::
