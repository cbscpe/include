;--------------------------------------------------------------------------
;
;	CopyName (local Routine)
;
;	Copy file/directory name from buffer at X to NameBuffer. The buffer at
;	X is assumed to contain a combined path to a file or a directory with
;	file/directory name separators. CopyName will copy up to the next 
;	separator, null or carriage return, whichever occurs first. This
;	function is supposed to be called successively to scan and process
;	a path.
;
;	Input:
;		X		Pointer to string
;		Z		Output Buffer for null terminated name element
;
;	Output:
;		X		Pointer after terminating character
;		r24		Terminating Character
;
;	Conditions:
;		T-bit cleared	Result has length 0
;		T-bit set	Result has length >0
;
;	Registers
;		none
;
;
CopyName:

	push	zl
	push	zh
	ldi	zl, low(NameBuffer)
	ldi	zh, high(NameBuffer)
;++++
;	sts	pprint+0, xl
;	sts	pprint+1, xh
;	sts	pprint+2, zl
;	sts	pprint+3, zh
;	call	print
;	.db	CR, LF
;	;	"----+----1----+----2----+"
;	.db	"Copy Name Entry     X->0x", 0x81, 0x80, " Z->0x", 0x83, 0x82, CR, LF, 0
;----
	clt
CopyNameLoop:
	ld	r24, X+
	st	Z+, r24
	cpi	r24, DELIM
	breq	CopyNameDone
	cpi	r24, 0x0d
	breq	CopyNameDone
	cpi	r24, 0x00
	breq	CopyNameDone
	set
	rjmp	CopyNameLoop	
;
;	Note that a compare clears the carry if the result is eq
;	hence we arrive here with carry cleared
;
CopyNameDone:
	st	-Z, zero
;++++
;	in	r16, CPU_SREG		; preserve T-Bit
;	sts	pprint+0, xl
;	sts	pprint+1, xh
;	sts	pprint+2, zl
;	sts	pprint+3, zh
;	sts	pprint+4, r24
;	ldi	r17, '0'
;	bld	r17, 0
;	sts	pprint+5, r17
;	call	print
;	;	"----+----1----+----2----+"
;	.db	"Copy Name Delimiter 0x", 0x84, SPACE, CR, LF
;	.db	"T-Bit              '", 0x95, "'", CR, LF
;	.db	"Copy Name Exit      X->0x", 0x81, 0x80, " Z->0x", 0x83, 0x82, CR, LF, 0
;	out	CPU_SREG, r16
;----
	pop	zh
	pop	zl
	ret


