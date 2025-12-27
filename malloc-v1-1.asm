;--------------------------------------------------------------------------
;
;	Malloc() und Free() als Fingerübung in Assembler
;
;	Wie ich später festgestellt habe entspricht die Funktion dem Beispiel
;	in C aus K&R. Die freien Speicherbereich sind immer in
;	aufsteigender Addresse miteinandenr verlinkt und beim Einfügen wird
;	sichergestellt dass das auch so bleibt. Dadurch kann Free() benach-
;	barte Bereiche wieder zusammenfügen (defragmentation). 
;
;	Sonst sind keine Optimierungen eingebaut. Eigentlich sollte man aber
;	mindestens den First-Match durch einen Best-Match Algorithmus
;	ersetzen, vor allem wenn die Grösse der angeforderten Speicher
;	bereiche stark variiert verhindert man so dass zu früh kein grosser
;	Block mehr gefunden wird. Wer weiss vielleicht baue ich das noch ein.
;
;	Zur Verwaltung ist vor jedem Block die Länge abgespeichert. Die Links
;	zeigen immer auf die Länge des nächsten Block. Die Addresse die der 
;	Benutzer erhält oder zurückgeben muss ist natürlich die Startaddresse 
;	des Datenteils.
;
;	2018-05-21	using one of the pointer registers is not optimal
;			in most cases the pointer returned is stored either
;			in a memory location or a data structure which itself
;			uses one of the pointer register pairs. In other words
;			using a pointer register as transfer register requires
;			that the caller does not currently use the pointer
;			register pair, in our case Y. Therefore we change
;			it from Y to r25:r24
;
;	2018-05-22	replaced the first match with a best match algorithm
;	2024-05-26	use sbiw/adiw to check for null value
;			malloc instead of using carry make sure r25:r24 is zero
;			when allocation failes
;
;	Input:
;			r25:r24	Number of bytes, must be at least 2
;	Output:
;			r25:r24	pointer to the buffer or zero if failed
;	Registers:
;			none
;
malloc:

	push	r0
	push	r1
	push	xl
	push	xh
	push	yl
	push	yh
	push	zl
	push	zh

	sbiw	r25:r24, 2	; need to request at least 2 bytes
	brmi	mfailed		; invalid amount

	adiw	r25:r24, 2+2	; Minimal Size incl. header
	ldi	yl, low(heap)
	ldi	yh, high(heap)	; Address of list header
	clt			; Assume no candidate found
mloop:
	movw	Z, Y		; Copy address of current header
	ldd	yl, Z+2		; Get pointer to next block
	ldd	yh, Z+3		;
;
;heap:
;   +----+          +----+          +----+          +----+          +----+
;   |size|   +->    |size|   +->    |size|   +->    |size|   +->    |size|
;   +----+   |      +----+   |      +----+   |      +----+   |      +----+
;   |head|  -+      |    |  -+      |    |  -+      |    |  -+      | 0  |
;   +----+          +----+          +----+          +----+          +----+
;                   |    |          |    |          |    |          |    |
;                   |    |          |    |          |    |          |    |
;                   |    |          |    |          |    |          |    |
;                   |    |          |    |          |    |          |    |
;                   |    |          |    |          |    |          |    |
;     Z              Y                                                    
;                    Z               Y                                    
;                                    Z               Y                    
;                                                    Z               Y    
;
	sbiw	yh:yl, 0
	breq	mlistend	; reached the end check if we have a block
	ldd	r0, Y+0		; Get length of next block
	ldd	r1, Y+1		;
	cp	r0, r24
	cpc	r1, r25
	brlo	mloop		; too short
	adiw	r25:r24, 4	; 
	cp	r0, r24
	cpc	r1, r25		; big enough for a split
	brlo	mfit		; no so we have a best fit
	sbiw	r25:r24, 4	; 
	set			; We have a block
	movw	X, Y		; remember it's address
	rjmp	mloop		; try all blocks

;
;	Found a block (Y) which has exact size
;
mfit:
	movw	r25:r24, Y	; Copy pointer
	adiw	r25:r24, 2	; Skip Header
	ldd	r0, Y+2		; Get the pointer to the next block
	ldd	r1, Y+3
	std	Z+2, r0		; And let the previous block point to
	std	Z+3, r1		; it, ie. we just remove the block from list.
	clc			; r1:r0 might be 0 as well if by coincidence
	rjmp	mfinish		; the last block is a best fit
;
;	We have gone through the list of blocks check if we found one
;
mlistend:
	brts	mfound
mfailed:
	clr	r24
	clr	r25
	sec			; Assume no buffer found
	rjmp	mfinish		; yes that's bad
;
;	Found a block (Y) which is larger then requested size 
;
mfound:
	ld	r0, X+		; Get length of buffer
	ld	r1, X+
	sub	r0, r24		; minus number of bytes requested
	sbc	r1, r25				
	st	-X, r1		; new length of buffer
	st	-X, r0
	add	xl, r0		; Calculate address of allocated buffer
	adc	xh, r1
	st	X+, r24		; Set size of allocated buffer and
	st	X+, r25		; Advance pointer to data part
	movw	r25:r24, xh:xl	; Return this pointer
	clc

mfinish:
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	pop	r1
	pop	r0
	ret

;--------------------------------------------------------------------------
;
;	free() a previously allocated buffer, note that you must not call free
;	with a buffer that has never been allocated or has allready been freed.
;	This will be fatal and there is no way we can check that with the
;	current implementation. 
;	
;	Input:
;			r25:r24	address of the block to be released.
;
#ifdef debugmalloc
freedebug:
	sts		pprint+6, temp
	sts		pprint+0, xl
	sts		pprint+1, xh
	sts		pprint+2, yl
	sts		pprint+3, yh
	sts		pprint+4, zl
	sts		pprint+5, zh
	call	print
	.db		"free0", 0x86," X: 0x", 0x81, 0x80, ", Y: 0x", 0x83, 0x82, ", Z: 0x", 0x85, 0x84, 0x0d, 0x0a, 0x00, 0x00
	ret
#endif
free:
	push	r0
	push	r1
	push	xl
	push	xh
	push	yl
	push	yh
	push	zl
	push	zh
	movw	Y, r25:r24	;
	sbiw	Y, 2		; pointer to the size word
	ldi	xl, low(heap)
	ldi	xh, high(heap)
free010:
	movw	Z, X
	ldd	xl, Z+2		; Address of next block in free list
	ldd	xh, Z+3
;
;	Z	current buffer
;	Y	buffer to be released
;	X	next buffer in free list
;
;	Buffers are always linked in order of increasing addresses therefore
;	Z is always smaller than X, Z<X, we now need to find Z and X whith
;	Z<Y<X
;
#ifdef debugmalloc
	ldi	temp, 0x10
	rcall	freedebug
#endif
	movw	r1:r0, X
	or	r0, r1
	breq	free030		; End of list reached
;
;
;
	cp	yl, zl
	cpc	yh, zh		; Y is even less than Y so try next
	brlo	free010
;
;	Case 1	Z<X<Y try next
;	Case 1	Z<Y<X we are done
;
#ifdef debugmalloc
	ldi	temp, 0x11
	rcall	freedebug
#endif
	cp	xl, yl		; Our next buffer above the current
	cpc	xh, yh
	brlo	free010		; Make sure we reach the end
;
;	We arrive here only when Z<Y<X
;
#ifdef debugmalloc
	ldi	temp, 0x12
	rcall	freedebug
#endif
;
;	Either Z<Y<X or Z<Y and X=0
;
free030:
#ifdef debugmalloc
	ldi	temp, 0x30
	rcall	freedebug
#endif
	std	Z+2, yl
	std	Z+3, yh
	std	Y+2, xl
	std	Y+3, xh
;
;	Check if the previous block (Z) is adjacent to the block we return (Y)
;
	ldd	r24, Z+0	; Get Length of previous block
	ldd	r25, Z+1
	add	r24, zl		; Add it's address
	adc	r25, zh
	cp	r24, yl		; Compare with address of the released block
	cpc	r25, yh
	brne	free040		; not adjacent
;
;	They are adjacent
;
#ifdef debugmalloc
	ldi	temp, 0x31
	rcall	freedebug
#endif
	ldd	r24, Z+0	; Get length of previous block
	ldd	r25, Z+1
	ldd	r0, Y+0		; Get length of released block
	ldd	r1, Y+1
	add	r24, r0		; Add lengths together
	adc	r25, r1
	std	Z+0, r24	; Store length into combined block
	std	Z+1, r25
	std	Z+2, xl		; End let it point to next block (could be zero)
	std	Z+3, xh
	movw	Y, Z		; Now released block is combined block for next check
;
;	check if released or combined block (Y) is adjacent to the next block (X)
;
free040:
#ifdef debugmalloc
	ldi	temp, 0x40
	rcall	freedebug
#endif
	ldd	r24, Y+0	; Get length of released/combined block
	ldd	r25, Y+1
	add	r24, yl		; Add it's address
	adc	r25, yh
	cp	r24, xl		; Compare with address of next block
	cpc	r25, xh
	brne	free050		; not adjacent or X is zero
;
;	They are adjacent, note X is not zero and points to a real block
;
#ifdef debugmalloc
	ldi	temp, 0x41
	rcall	freedebug
#endif
	ldd	r24, Y+0	; Get length of released/combined block
	ldd	r25, Y+1
	ld	r0, X+		; Get length of next block
	ld	r1, X+
	add	r24, r0		; Add lengths together
	adc	r25, r1
	std	Y+0, r24	; Store new length of combined block
	std	Y+1, r25
	ld	r0, X+		; Get pointer in next block		
	ld	r1, X+
	std	Y+2, r0		; And save it in pointer of combined block
	std	Y+3, r1
;
;	
;
free050:
	clc
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	pop	r1
	pop	r0
	ret
