%[flags][width][.precision][length]specifier


specifier
---------

c	Character
d	Decimal
o	Octal
s	String
u	Unsigned
x	Hexadecimal
%	%

non-standard specifiers
-----------------------

R	Carriage Return + Line Feed
T	Tab



flags
----

-	left justified

width
-----

nnn	decimal number

precision
---------

not implemented

length
------

b	8-bit
h	16-bit
a	24-bit
l	32-bit


;--------------------------------------------------------------------------
;
;	mprint routine to print a message
;
;	usage
;
;	call	mprint
;	.dw	<msgptr>, <dataptr>
;
;	It makes use of the feature of the AVR128 mcu family that can map a 32kbyte
;	range of the flash to the normal data address space. 
;
printf:
	push	yl			; Save pointer registers
	push	yh
	push	zl
	push	zh
	in	yl, SPL
	in	yh, SPH			; get stack pointer
	in	yl, CPU_SPL
	in	yh, CPU_SPH
	push	xh			; Save additional registers
	push	xl
	push	r25
	push	r24
	push	r23
	push	r22
	ldd	zl, Y+6			; get return address
	ldd	zh, Y+5
;-	sts	0x5000, yl	
;-	sts	0x5001, yh
;-	sts	0x5002, zl
;-	sts	0x5003, zh
	adiw	zh:zl, 2		; increment return address (skip msg pointer)
	std	Y+6, zl			; update return address
	std	Y+5, zh
;-	sts	0x5004, zl
;-	sts	0x5005, zh
	sbiw	zh:zl, 2		; go back to msg pointer
	lsl	zl			; Make byte index
	rol	zh
	lpm	yl, Z+			; get message pointer
	lpm	yh, Z+
	lpm	xl, Z+			; get data pointer
	lpm	xh, Z+
;-	sts	0x5006, yl
;-	sts	0x5007, yh
;	ldi	r24, CR
;	call	serout
;	ldi	r24, LF
;	call	serout
print010:	
	ld	r24, Y+
	tst	r24
	breq	mprint020
	call	serout
	rjmp	mprint010
mprint020:
;	ldi	r24, CR
;	call	serout
;	ldi	r24, LF
;	call	serout
	pop	r22
	pop	r23
	pop	r24
	pop	r25
	pop	xl
	pop	xh
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	ret

;
;	%[flags][width][.precision][length]specifier
;
mprint100:
;
;	flags
;


;
;	width
;
	clr	r25			; width
mprint110:
	cpi	r24, '0'
	brlo	mprint120
	cpi	r24, '9'+1
	brlo	mprint120
	add	r25, r25
	mov	zl, r25
	add	r25, r25
	add	r25, r25
	add	r25, zl			; multiply r25 with 10
	andi	r24, 0x0f
	add	r25, r24
	ld	r24, X+
	tst	r24
	brne	mprint110
	rjmp	mprint090
;
mprint120:

;
;	length
;

;
;	specifier
;