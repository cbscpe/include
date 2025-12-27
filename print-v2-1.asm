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
;	2019-01-05	Version 1.1 generalize format
;	2020-10-08	Add RADIX50
;	2021-11-06	New single character commands
;			8	1 byte hex with leading zero
;			9	1 character
;			A	2 byte octal with leading zero
;			B	3 byte octal as 22-bit address
;			C	2 byte decimal right justified xxxxx without leading zero
;			D	4 byte decimal right justified x'xxx'xxx'xxx without leading zero		
;			E	2 byte RADIX50
;			F	1 byte decimal left justified without leading zero
;
;	2021-11-27	Major revision v2
;			Stack Only Version with inline string
;			No named registers
;			All registers preserved
;			
;	2022-12-22	uint8_t left justified
;	2024-01-07	avoid using register zero
;
;	call	print
;	.db	<string>
;
	.cseg
print:
	push	yl
	push	yh
	push	zl
	push	zh
	.ifdef CPU_SPL
	in	yl, CPU_SPL
	in	yh, CPU_SPH
	.endif
	.ifdef SPL
	in	yl, SPL
	in	yh, SPH
	.endif
	ldd	zl, Y+6
	ldd	zh, Y+5
	lsl	zl			; Make byte index
	rol	zh

	push	r20
	push	r21
	push	r22
	push	r23
	push	r24

print010:
	lpm	r24, Z+			; Print until a 0x00 is reached
	tst	r24
	brne	print020
	adiw	zh:zl, 1		; Align to code after message
	lsr	zh
	ror	zl

	pop	r24
	pop	r23
	pop	r22
	pop	r21
	pop	r20

	.ifdef CPU_SPL
	in	yl, CPU_SPL
	in	yh, CPU_SPH
	.endif
	.ifdef SPL
	in	yl, SPL
	in	yh, SPH
	.endif
	std	Y+6, zl
	std	Y+5, zh
	pop	zh
	pop	zl
	pop	yh
	pop	yl

printret:
	ret


print020:
	brmi	print030
;	cpi	r24, CR			; Carriage Return
;	breq	print025
;	cpi	r24, LF			; Linefeed
;	breq	print025
;	cpi	r24, 0x09		; Tabulator
;	breq	print025
;	rcall	printret		; Process special characters
;	rjmp	print010		; For the moment all are no-op
;print025:	
	call	serout
	rjmp	print010

print030:
	mov	yl, r24
	andi	yl, 0x0f
	clr	yh
	subi	yl, low(-pprint)
	sbci	yh, high(-pprint)
	cpi	r24, 0x90
	brsh	printx90
;
;	Print byte hex
;
	ld	r24, Y
	swap	r24
	rcall	printbytehex010
	ld	r24, Y
	rcall	printbytehex010
	rjmp	print010	

printbytehex010:
	andi	r24, 0x0F
	ori	r24, '0'
	cpi	r24, '0'+10
	brlo	printbytehex020
	subi	r24, '0'-'A'+10
printbytehex020:
	jmp	serout
;
printx90:
	cpi	r24, 0xA0
	brsh	printxa0
;
;	Print character
;
	ld	r24, Y
	cpi	r24, 0x20
	brcs	printx90a
	cpi	r24, 0x7f
	brcs	printx90b
printx90a:
	ldi	r24, '.'
printx90b:
	call	serout
	rjmp	print010
;
;
;	16-bit Octal
;
printxa0:
	cpi	r24, 0xB0
	brsh	printxb0
;
;	print octal word
;
	ld	r20, Y+			; lower byte
	ld	r21, Y+			; upper byte
	lsl	r20
	rol	r21
	rol	r24			; shift top bit
	andi	r24, 0x01		; 
	ori	r24, '0'		; 
	call	serout
	rjmp	printoctal5		; print remaining 5 digits
;
;
;
printxb0:	
	cpi	r24, 0xC0
	brsh	printxc0
;
;	Print 22-bit address octal
;
	ldd	r22, Y+2		; extended byte
	ldi	r24, '0'		; Assume 0
	sbrc	r22, 5
	inc	r24			; No its 1
	call	serout
	ldd	r24, Y+2		; extended byte
	lsr	r24
	lsr	r24			; bits 2-4 to 0-2
	andi	r24,0x07
	ori	r24, '0'
	call	serout
	ldd	r24, Y+2
	andi	r24, 0x03		;
	ldd	r20, Y+0
	ldd	r21, Y+1
	lsl	r20
	rol	r21
	rol	r24
	ori	r24, '0'
	call	serout

printoctal5:
	rcall	printaddrnext
	rcall	printaddrnext
	rcall	printaddrnext
	rcall	printaddrnext
	rcall	printaddrnext
	rjmp	print010

printaddrnext:
	lsl	r20
	rol	r21
	rol	r24
	lsl	r20
	rol	r21
	rol	r24
	lsl	r20
	rol	r21
	rol	r24
	andi	r24, 0x07
	ori	r24, '0'
	jmp	serout

printxc0:
	cpi	r24, 0xD0
	brsh	printxd0
	rcall	printxc0sub
	rjmp	print010

printxd0:	
	cpi	r24, 0xE0
	brsh	printxe0
	rcall	printxd0sub
	rjmp	print010

printxe0:
	cpi	r24, 0xF0
	brsh	printxf0
	rcall	printxe0sub
	rjmp	print010
	
printxf0:
	rcall	printxf0sub
	rjmp	print010
;--------------------------------------------------------------------------
;
;
.macro	digit4
	ldi	r24, '0'
cvtloop:
	subi	r20, byte1(@0)
	sbci	r21, byte2(@0)
	sbci	r22, byte3(@0)
	sbci	r23, byte4(@0)
	brmi	cvtdone
	set
	inc	r24
	rjmp	cvtloop
cvtdone:
	brts	cvtdig
	ldi	r24, ' '
cvtdig:
	call	serout
	subi	r20, byte1(-@0)
	sbci	r21, byte2(-@0)
	sbci	r22, byte3(-@0)
	sbci	r23, byte4(-@0)
.endmacro	

.macro	digit2
	ldi	r24, '0'
cvtloop:
	subi	r20, low(@0)
	sbci	r21, high(@0)
	brcs	cvtdone
	set
	inc	r24
	rjmp	cvtloop
cvtdone:
	brts	cvtdig
	ldi	r24, ' '
cvtdig:
	call	serout
	subi	r20, low(-@0)
	sbci	r21, high(-@0)
.endmacro	

.macro	separator
	ldi	r24, ' '
	brtc	cvtsep
	ldi	r24, '\''
cvtsep:
	call	serout
.endmacro

;--------------------------------------------------------------------------
;
;	Convert 16-bit binary to 5 digit decimal with leading zero suppression
;
printxc0sub:
	ld	r20, Y+
	ld	r21, Y+
	clt

	digit2	10000
	digit2	1000
	digit2	100
	digit2	10
	mov	r24, r20
	ori	r24, '0'
	call	serout

	ret

;--------------------------------------------------------------------------
;
;	Convert 32-bit binary to 10 digit decimal with leading zero
;	suppression and thousends delimiter
;
printxd0sub:

	ld	r20, Y+			; Get 32-bit integer
	ld	r21, Y+
	ld	r22, Y+
	ld	r23, Y+
	clt

	digit4	1000000000		; We convert the slow way
	separator			; a 32-bit integer to
	digit4	100000000		; an unsigned decimal with 
	digit4	10000000		; thousands separator
	digit4	1000000
	separator
	digit4	100000
	digit4	10000
	digit4	1000
	separator
	digit4	100
	digit4	10
	mov	r24, r20		; Convert last digit to ASCII
	ori	r24, '0'		; 
	call	serout
	
	ret

;--------------------------------------------------------------------------
;
;
.equ	rad2	= 0x0640		; 50(8) * 50(8)
.equ	rad1	= 0x0028		; 50(8)

.macro	rad50
	clr	r24
cvtloop:
	subi	r20, low(@0)
	sbci	r21, high(@0)
	brcs	cvtdone
	set
	inc	r24
	rjmp	cvtloop
cvtdone:
	subi	r20, low(-@0)
	sbci	r21, high(-@0)
.endmacro	


printxe0sub:

	ld	r20, Y+
	ld	r21, Y+
	push	zl
	push	zh
	rad50	rad2
	ldi	zl, low(2*rad50tab)
	ldi	zh, high(2*rad50tab)
	add	zl, r24
	clr	r24
	adc	zh, r24
	lpm	r24, Z
	call	serout
	rad50	rad1
	ldi	zl, low(2*rad50tab)
	ldi	zh, high(2*rad50tab)
	add	zl, r24
	clr	r24
	adc	zh, r24
	lpm	r24, Z
	call	serout
	ldi	zl, low(2*rad50tab)
	ldi	zh, high(2*rad50tab)
	add	zl, r20
	clr	r24
	adc	zh, r24
	lpm	r24, Z
	call	serout
	pop	zh
	pop	zl
	ret		

rad50tab:
	.db	" ABCDEFGHIJKLMNOPQRSTUVWXYZ$.%0123456789"
	
;--------------------------------------------------------------------------
;
;	Convert uint8_t to decimal without leading 0/space
;
printxf0sub:
	ld	r20, Y+
	cpi	r20, 10
	brlo	printxf0sub040
	cpi	r20, 100
	brlo	printxf0sub020
	ldi	r24, '1'
	subi	r20, 100
	cpi	r20, 100
	brlo	printxf0sub010
	ldi	r24, '2'
	subi	r20, 100
printxf0sub010:
	call	serout
printxf0sub020:
	ldi	r24, '0'
printxf0sub025:
	cpi	r20, 10
	brlo	printxf0sub030
	subi	r20, 10
	inc	r24
	rjmp	printxf0sub025
printxf0sub030:
	call	serout
printxf0sub040:
	mov	r24, r20
	ori	r24, '0'
	call	serout
	ret	
	

