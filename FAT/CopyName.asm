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
	pop	zh
	pop	zl
	ret


