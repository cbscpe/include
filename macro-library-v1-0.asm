;--------------------------------------------------------------------------
;
;	General Macro Definitions
;
.macro	align             ;align to (1<<@0)
alignfromhere:
      .if (alignfromhere & ((1<<@0)-1))   ;if not already aligned
         .org  (alignfromhere & (0xffff<<@0)) + (1<<@0)
      .endif
.endmacro

.macro	uppercase
	cpi		@0, 0x60			; lower case ?
	brlo	l1
	andi	@0, 0x5F			; Perhaps yes make sure we have upper case only
l1:
.endmacro
;--------------------------------------------------------------------------
;
;	Based on the CRC subroutines from 6502 emulator of daryl rictor
;
;	Inline Macro to calculate CRC byte-wise. This saves the cycles used
;	by rcall and ret. It assumes a register as the parameter with the
;	next byte. This version assumes that the CRC tables are 256byte aligned. 
;	Two global register definitions are used to hold the current CRC, the 
;	CRC is the standard 16-CRC used by xmodem, SD-Cards, mass storage etc..
;	!!!This macro destroys the input register and the Z pointer!!!
;
.macro	updcrc
	mov		zl, @0					;  1
	eor		zl, crch				;  1
	ldi		zh, high(2*crchi)		;  1
	lpm		crch, Z					;  3
	eor		crch, crcl				;  1
	dec		zh						;  1
	lpm		crcl, Z					;  3
.endmacro

