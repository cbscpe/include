;--------------------------------------------------------------------------
;
;	General Macro Definitions

;--------------------------------------------------------------------------
;
;	Align data or code on a address that is 0 mod(2^^n) this is
;	used to create nice addresses or used for tables or data
;	structures that need to be aligned. E.g. 256byte ring buffers
;	that only use a byte index but have a fixed highorder byte 
;	address
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
.macro	ucase
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
	mov	zl, @0			;  1
	eor	zl, crch		;  1
	ldi	zh, high(2*crchi)	;  1
	lpm	crch, Z			;  3
	eor	crch, crcl		;  1
	dec	zh			;  1
	lpm	crcl, Z			;  3
.endmacro
;
;	New Macro CRC which takes the registers used to hold the 16-bit CRC
;	values as parameter 2 and 3 as it is not always a good idea to have
;	globally defined register definitions. We assume the CRC tables to 
;	be 256-byte page alligend.
;
.macro	crc;	byte, crcl, crch
	mov	zl, @0			;  1
	eor	zl, @2			;  1
	ldi	zh, high(2*crchi)	;  1
	lpm	@2, Z			;  3
	eor	@2, @1			;  1
	dec	zh			;  1
	lpm	@1, Z			;  3
.endmacro

;--------------------------------------------------------------------------
;
;	record macro's
;
;	Used to create constants that are offsets in a control
;	block or other data structures use as
;
;	recordstart	pcb
;	record		pcb, queue, 2
;	record		pcb, status, 1
;	record		pcb, id, 1
;	record		pcb, start, 4
;	record		pcb, drvtab, 2
;	record		pcb, psector, 4
;	record		pcb, ptype, 1
;	record		pcb, poff, 1
;	recordend	pcb, len
;
;	The main purpose is the use in ldd and std instructions. Note
;	that the offset for these instruction is limited to 63 bytes.
;
.set recordlength = -1
.macro	recordstart
.set recordlength = 0
.endmacro

.macro	recordcont
.set recordlength = @0##_##@1
.endmacro

.macro	record
.equ	@0##_##@1 = recordlength
.set recordlength = recordlength + @2
.endmacro	

.macro	recordend
.equ	@0##_##@1 = recordlength
.endmacro	
