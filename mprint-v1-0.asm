 ;--------------------------------------------------------------------------
;
;	mprint routine to print a message
;
;	this is work in progress and will replace the print routine 
;	the goal is to have something equivalent to sprint()
;
;	usage
;
;	call	mprint
;	.dw	<msgptr>
;
;	It makes use of the feature of the AVR128 mcu family that can map a 32kbyte
;	range of the flash to the normal data address space. Therefore the pointer
;	must match the address in the data space and the messages must be put
;	in the mapped portion of the flash
;
mprint:
	push	yl			; Save two pointer registers
	push	yh
	push	zl
	push	zh
	in	yl, CPU_SPL		; get stack pointer
	in	yh, CPU_SPH
	ldd	zl, Y+6			; get return address
	ldd	zh, Y+5
	adiw	zh:zl, 1		; increment return address (skip msg pointer)
	std	Y+6, zl			; update return address
	std	Y+5, zh
	sbiw	zh:zl, 1		; go back to msg pointer
	lsl	zl			; Make byte index
	rol	zh
	lpm	yl, Z+			; get message pointer
	lpm	yh, Z+
	push	r24
	push	r25
	push	xl
	push	xh
	ldi	xl, low(pprint)
	ldi	xh, high(pprint)
mprint010:	
	ld	r24, Y+
	tst	r24
	breq	mprint090
	cpi	r24, '%'
	brne	mprint080
	ld	r24, Y+
	tst	r24
	breq	mprint090
	cpi	r24, '%'
	breq	mprint080
	cpi	r24, 'c'
	brne	mprint020
	ld	r24, X+			; %c
	rjmp	mprint080
mprint020:
	cpi	r24, 'x'
	brne	mprint080		; %x
	ldi	r24, '0'
	call	serout
	ldi	r24, 'x'
	call	serout
	ld	r24, X+
	mov	zl, r24
	andi	r24, 0xF0
	swap	r24
	ori	r24, '0'
	cpi	r24, '9'+1
	brlo	mprint021
	subi	r24, ('0'-'A')
mprint021:
	call	serout
	movw	r24, zl
	andi	r24, 0xF0
	swap	r24
	ori	r24, '0'
	cpi	r24, '9'+1
	brlo	mprint080
	subi	r24, ('0'-'A')

mprint080:
	call	serout
	rjmp	mprint010
mprint090:
	pop	xh
	pop	xl
	pop	r25
	pop	r24
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	ret
