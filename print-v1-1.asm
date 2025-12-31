;
;	Print routine area and return status area. Note that print has one
;	16 byte area that it can print. We put the return status area into
;	the 16 byte area so we do not need to move data around.
;
	.dseg
#define printstack
#ifdef  printstack
;printsave:	.byte	4					; only required for debugging
#else
printsave:	.byte	2					; save storage for "print" routine
#endif
pprint:		.byte	10					; Must be exactly 10 bytes
pcrc:		.byte	2					; Checksum 
.equ		ppcrc	= 0x80 + pcrc - pprint
piostatus:	.byte	2					; Must follow pprint
ploop:		.byte	2
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
	ret


print020:
	brmi	print030
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
;				8		1 byte hex with leading zero
;				9		1 character
;				A		2 byte octal with leading zero
;				B		3 byte octal as 22-bit address
;				C		2 byte decimal right justified xxxxx without leading zero
;				D		4 byte decimal right justified x'xxx'xxx'xxx without leading zero		
;				E
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
	brhs	printxd0
	
	rcall	printxc0sub


	rjmp	print010

printxd0:	
	rjmp	print010
;
;	Hand made print 16-bit as decimal
;
printxc0sub:
	push	r24
	push	r25
	ld		r24, Y+
	ld		r25, Y+
	clt
;
;	Digit 5
;
	ldi		char, '0'
printxc0loop5:
	subi	r24, low(10000)
	sbci	r25, high(10000)
	brmi	printxc0done5
	set
	inc		char
	rjmp	printxc0loop5
printxc0done5:
	brts	printxc0dig5
	ldi		char, ' '
printxc0dig5:
	call	serout
	subi	r24, low(-10000)
	sbci	r25, high(-10000)
;
;	Digit 4
;
	ldi		char, '0'
printxc0loop4:
	subi	r24, low(1000)
	sbci	r25, high(1000)
	brmi	printxc0done4
	set
	inc		char
	rjmp	printxc0loop4
printxc0done4:
	brts	printxc0dig4
	ldi		char, ' '
printxc0dig4:
	call	serout
	subi	r24, low(-1000)
	sbci	r25, high(-1000)
;
;	Digit 3
;
	ldi		char, '0'
printxc0loop3:
	subi	r24, low(100)
	sbci	r25, high(100)
	brmi	printxc0done3
	set
	inc		char
	rjmp	printxc0loop3
printxc0done3:
	brts	printxc0dig3
	ldi		char, ' '
printxc0dig3:
	call	serout
	subi	r24, low(-100)
	sbci	r25, high(-100)
;
;	Digit 2
;
	ldi		char, '0'
printxc0loop2:
	subi	r24, low(10)
	sbci	r25, high(10)
	brmi	printxc0done2
	set
	inc		char
	rjmp	printxc0loop2
printxc0done2:
	brts	printxc0dig2
	ldi		char, ' '
printxc0dig2:
	call	serout
	subi	r24, low(-10)
	sbci	r25, high(-10)
;
;	Digit 1
;
	mov		char, r24
	ori		char, '0'
	call	serout
	pop		r25
	pop		r24
	ret
