;
;	Print routine area and return status area. Note that print has one
;	16 byte area that it can print. We put the return status area into
;	the 16 byte area so we do not need to move data around.
;
	.dseg
#define printstack						; no impure data area
#ifdef  printstack
;printsave:	.byte	4					; only required for debugging
#else
printsave:	.byte	2					; save storage for "print" routine
#endif
pprint:		.byte	10					; Must be exactly 10 bytes
pcrc:		.byte	2					; Checksum 
piostatus:	.byte	2					; Must follow pprint
ploop:		.byte	2

.equ		ppcrc	= 0x80 + pcrc - pprint
.equ		ppiostatus = 0x80 + piostatus - pprint

;--------------------------------------------------------------------------
;
;	Print Inline Textmessages with inline values
;
;	The text is placed inline after the "call print" statement. The
;	print routine will use the return address to retrieve the message.
;	The message must be terminated with 0x00. Print will then adjust
;	the return address to make it word aligned and return to the caller
;	just after the message. The message must have an even number of bytes
;	else the assembler will throw a warning and just align the message by
;	addding a 0x00 padding byte.
;
;	Message characters with the MSB set will be treated as format character.
;	The lower nibble is treated as index into the pprint area and the higher
;	nibble as formatting code
;
	.cseg
print:
#ifdef  printstack
	push	r0
	push	temp
	push	char
	push	yl
	push	yh
	push	zl
	push	zh
	in		yl, SPL
	in		yh, SPH
	ldd		zl, Y+9
	ldd		zh, Y+8
#else
	sts		printsave, zl
	sts		printsave+1, zh			; Save registers
	pop		zh
	pop		zl						; Get PC after call print

	push	r0
	push	temp
	push	char
	push	yl
	push	yh
#endif	
	lsl		zl						; Make byte index
	rol		zh

print010:
	lpm		char, Z+				; Print until a 0x00 is reached
	tst		char
	brne	print020
	adiw	zh:zl, 1				; Align to code after message
	lsr		zh
	ror		zl

#ifdef  printstack
	in		yh, SPH
	in		yl, SPL
	std		Y+9, zl
	std		Y+8, zh
	pop		zh
	pop		zl
	pop		yh
	pop		yl
	pop		char
	pop		temp
	pop		r0
#else
	pop		yh
	pop		yl
	pop		char
	pop		temp
	pop		r0
	
	push	zl
	push	zh						; Store return address
	lds		zl, printsave
	lds		zh, printsave+1			; Restore registers
#endif

printret:
	ret


print020:
	brmi	print030
;	cpi		char, CR				; Carriage Return
;	breq	print025
;	cpi		char, LF				; Linefeed
;	breq	print025
;	cpi		char, 0x09				; Tabulator
;	breq	print025
;	rcall	printret				; Process special characters
;	rjmp	print010				; For the moment all are no-op
;print025:	
	call	serout
	rjmp	print010

print030:
	mov		yl, char
	andi	yl, 0x0f
	clr		yh
	subi	yl, low(-pprint)
	sbci	yh, high(-pprint)
;
;	2019-01-05	Version 1.1 generalize format
;	2020-10-08	Add RADIX50
;	2021-11-06	New single character commands
;				8		1 byte hex with leading zero
;				9		1 character
;				A		2 byte octal with leading zero
;				B		3 byte octal as 22-bit address
;				C		2 byte decimal right justified xxxxx without leading zero
;				D		4 byte decimal right justified x'xxx'xxx'xxx without leading zero		
;				E		2 byte RADIX50
;				F
;
	cpi		char, 0x90
	brsh	printx90
;
;	Print byte hex
;
	ld		char, Y
	swap	char
	rcall	printbytehex010
	ld		char, Y
	rcall	printbytehex010
	rjmp	print010	

printbytehex010:
	andi	char, 0x0F
	ori		char, '0'
	cpi		char, '0'+10
	brlo	printbytehex020
	subi	char, '0'-'A'+10
printbytehex020:
	jmp		serout
;
printx90:
	cpi		char, 0xA0
	brsh	printxa0
;
;	Print character
;
	ld		char, Y
	cpi		char, 0x20
	brcs	printx90a
	cpi		char, 0x7f
	brcs	printx90b
printx90a:
	ldi		char, '.'
printx90b:
	call	serout
	rjmp	print010
;
printxa0:
	cpi		char, 0xB0
	brsh	printxb0
;
;	print octal word
;
	ld		r0, Y+				; lower byte
	ld		temp, Y+			; upper byte
	lsl		r0
	rol		temp
	rol		char				; shift top bit
	andi	char, 0x01			; 
	ori		char, '0'			; 
	call	serout
	rjmp	printoctal5			; print remaining 5 digits
;
printxb0:	
	cpi		char, 0xC0
	brsh	printxc0
;
;	Print address octal
;
	ldd		temp, Y+2			; extended byte
	ldi		char, '0'			; Assume 0
	sbrc	temp, 5
	inc		char				; No its 1
	call	serout
	ldd		char, Y+2			; extended byte
	lsr		char
	lsr		char				; bits 2-4 to 0-2
	andi	char,0x07
	ori		char, '0'
	call	serout
	ldd		char, Y+2
	andi	char, 0x03			;
	ldd		r0, Y+0
	ldd		temp, Y+1
	lsl		r0
	rol		temp
	rol		char
	ori		char, '0'
	call	serout

printoctal5:
	rcall	printaddrnext
	rcall	printaddrnext
	rcall	printaddrnext
	rcall	printaddrnext
	rcall	printaddrnext
	rjmp	print010

printaddrnext:
	lsl		r0
	rol		temp
	rol		char
	lsl		r0
	rol		temp
	rol		char
	lsl		r0
	rol		temp
	rol		char
	andi	char, 0x07
	ori		char, '0'
	jmp		serout

printxc0:
	cpi		char, 0xD0
	brsh	printxd0
	rcall	printxc0sub
	rjmp	print010

printxd0:	
	cpi		char, 0xE0
	brsh	printxe0
	rcall	printxd0sub
	rjmp	print010

printxe0:
	cpi		char, 0xF0
	brsh	printxf0
	rcall	printxe0sub
	rjmp	print010
	
printxf0:
	rjmp	print010
;--------------------------------------------------------------------------
;
;	Convert 16/32-bit interger to decimal with leading zeros suppressed and
;	in case of 32-bit with thousands separator. Not speed optimized.
;
.equ	d9	= 1000000000		; 0x3B9ACA00		4-bytes
.equ	d8	= 100000000			; 0x05F5E100		4-bytes
.equ	d7	= 10000000			; 0x00989680		3-bytes
.equ	d6	= 1000000			; 0x000F4240		3-bytes
.equ	d5	= 100000			; 0x000186A0		3-bytes
.equ	d4	= 10000				; 0x00002710		2-bytes
.equ	d3	= 1000				; 0x000003E8		2-bytes
.equ	d2	= 100				; 0x00000064		1-bytes
.equ	d1	= 10				; 0x0000000A		1-bytes

.macro	digit4
	ldi		char, '0'
cvtloop:
	subi	r24, low(@0)
	sbci	r25, high(@0)
	sbci	r26, byte3(@0)
	sbci	r27, byte4(@0)
	brmi	cvtdone
	set
	inc		char
	rjmp	cvtloop
cvtdone:
	brts	cvtdig
	ldi		char, ' '
cvtdig:
	call	serout
	subi	r24, low(-@0)
	sbci	r25, high(-@0)
	sbci	r26, byte3(-@0)
	sbci	r27, byte4(-@0)
.endmacro	

.macro	digit2
	ldi		char, '0'
cvtloop:
	subi	r24, low(@0)
	sbci	r25, high(@0)
	brmi	cvtdone
	set
	inc		char
	rjmp	cvtloop
cvtdone:
	brts	cvtdig
	ldi		char, ' '
cvtdig:
	call	serout
	subi	r24, low(-@0)
	sbci	r25, high(-@0)
.endmacro	

.macro	separator
	ldi		char, ' '
	brtc	cvtsep
	ldi		char, '\''
cvtsep:
	call	serout
.endmacro

;--------------------------------------------------------------------------
;
;	Convert 16-bit binary to 5 digit decimal with leading zero suppression
;
printxc0sub:
	push	r24
	push	r25
	ld		r24, Y+
	ld		r25, Y+
	clt

	digit2	d4
	digit2	d3
	digit2	d2
	digit2	d1
	mov		char, r24
	ori		char, '0'
	call	serout

	pop		r25
	pop		r24
	ret

;--------------------------------------------------------------------------
;
;	Convert 32-bit binary to 10 digit decimal with leading zero
;	suppression and thousends delimiter
;
printxd0sub:

	push	r24						; Save the registers
	push	r25
	push	r26
	push	r27
	ld		r24, Y+					; Get 32-bit integer
	ld		r25, Y+
	ld		r26, Y+
	ld		r27, Y+
	clt

	digit4	d9						; We convert the slow way
	separator						; a 32-bit integer to
	digit4	d8						; an unsigned decimal with 
	digit4	d7						; thousands separator
	digit4	d6
	separator
	digit4	d5
	digit4	d4
	digit4	d3
	separator
	digit4	d2
	digit4	d1
	mov		char, r24				; Convert last digit to ASCII
	ori		char, '0'				; 
	call	serout
	
	pop		r27
	pop		r26
	pop		r25
	pop		r24
	ret

;--------------------------------------------------------------------------
;
;
.equ	rad2	= 0x0640			; 50(8) * 50(8)
.equ	rad1	= 0x0028			; 50(8)

.macro	rad50
	clr		char
cvtloop:
	subi	r24, low(@0)
	sbci	r25, high(@0)
	brmi	cvtdone
	set
	inc		char
	rjmp	cvtloop
cvtdone:
	subi	r24, low(-@0)
	sbci	r25, high(-@0)
.endmacro	


printxe0sub:

	push	r24
	push	r25
	ld		r24, Y+
	ld		r25, Y+
	push	zl
	push	zh
	rad50	rad2
	ldi		zl, low(2*rad50tab)
	ldi		zh, high(2*rad50tab)
	add		zl, char
	adc		zh, zero
	lpm		char, Z
	call	serout
	rad50	rad1
	ldi		zl, low(2*rad50tab)
	ldi		zh, high(2*rad50tab)
	add		zl, char
	adc		zh, zero
	lpm		char, Z
	call	serout
	ldi		zl, low(2*rad50tab)
	ldi		zh, high(2*rad50tab)
	add		zl, r24
	adc		zh, zero
	lpm		char, Z
	call	serout
	pop		zh
	pop		zl
	pop		r25
	pop		r24
	ret		

rad50tab:
	.db	" ABCDEFGHIJKLMNOPQRSTUVWXYZ$.%0123456789"
	
	