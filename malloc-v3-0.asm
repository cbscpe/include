;--------------------------------------------------------------------------
;
;	malloc() and free() as small excersize in assembler
;
;	This pretty much corresponds to the example from the C book written
;	by K&R. The free memory blocks are always linked in ascending order
;	and when we insert a block we make sure the order is kept asceding.
;
;	Therefore free() can combine adjacent blocks again and automatically
;	defrag the blocks again.
;
;	Implemented is a best match algorithm, that is we will search the 
;	whole list of free blocks and in case we have a block of the exact
;	size will return this one rather than split a larger block
;
;	When allocating a block a 16-bit length word is prepended in the
;	administration. Each block is just identified by its address and
;	as we prepend with the length we know how long a block is when
;	free() is called and therefore we also can combine adjacent blocks
;	The user will receive the address of the firt free byte and has
;	to use the same address when calling free().
;
;	2022-01-03	dedicated software interrupt so we are sure that 
;			malloc and free are executed as an attomic entity
;			but without disabling Level1 interrupt, also as
;			Level0 interrupts cannot interrupt other Level0
;			interrupts the RTOS cannot interrupt malloc and free.
;	2024-03-09	The new RTOS pin change interrupt logic now just
;			asserts b_RTOS and does a normal return to continue
;			the routine that deasserted b_RTOS in level0 interrupt
;			mode. So we now share the PC interrupt and no longer
;			require a dedicated pin on a dedicated port.
;	2024-03-09	remove unecessary 'sec' and 'clc' as the success
;			of malloc() is shown when r25:r24 is not zero and
;			failure if r25:r24 is zero, no need for carry and
;			also the carry has no meaning in the ABI
;
;--------------------------------------------------------------------------
;
;	malloc()
;
;	Input:
;			r25:r24	Number of bytes, must be at least 2
;	Output:
;			r25:r24	pointer to the buffer, zero if not enough memory
;	Registers:
;			none
;
malloc:
	cbi	b_RTOS		; Trigger software interrupt
	push	r16		; save registers
	push	r17		;;
	push	xl		;;; here we will be already in interrupt
	push	xh		;;; level0 mode
	push	yl
	push	yh
	push	zl
	push	zh
malloc100:
	sbis	b_RTOS		;;; check ISR has been executed
	rjmp	malloc100	;;; 
	sbi	f_RTOS		; acknowledge interrupt
;
;
;
#ifdef tesout_malloc
	sts	tesoutent+2, r24
	sts	tesoutent+3, r25
#endif
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
	ldd	r16, Y+0	; Get length of next block
	ldd	r17, Y+1	;
	cp	r16, r24
	cpc	r17, r25
	brlo	mloop		; too short
	adiw	r25:r24, 4	; 
	cp	r16, r24
	cpc	r17, r25	; big enough for a split
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
	ldd	r16, Y+2	; Get the pointer to the next block
	ldd	r17, Y+3
	std	Z+2, r16	; And let the previous block point to
	std	Z+3, r17	; it, ie. we just remove the block from list.
;;;	clc			; r17:r16 might be 0 as well if by coincidence
	rjmp	mfinish		; the last block is a best fit
;
;	We have gone through the list of blocks check if we found one
;
mlistend:
	brts	mfound		; But we have already found a buffer
mfailed:
	clr	r24
	clr	r25
;;;	sec
	rjmp	mfinish
;
;	Found a block (Y) which is larger then requested size 
;
mfound:
	ld	r16, X+		; Get length of buffer
	ld	r17, X+
	sub	r16, r24		; minus number of bytes requested
	sbc	r17, r25				
	st	-X, r17		; new length of buffer
	st	-X, r16
	add	xl, r16		; Calculate address of allocated buffer
	adc	xh, r17
	st	X+, r24		; Set size of allocated buffer and
	st	X+, r25		; Advance pointer to data part
	movw	r25:r24, xh:xl	; Return this pointer
;;;	clc
mfinish:
#ifdef tesout_malloc
	lds	yl, tesoutptr+0
	lds	yh, tesoutptr+1
	ldi	r16, chk_malloc
	std	Y+0, r16
	lds	r16, jobid
	std	Y+1, r16
	lds	r16, tesoutent+2
	lds	r17, tesoutent+3
	std	Y+2, r16
	std	Y+3, r17
	std	Y+4, r24
	std	Y+5, r25
	lds	r16, iotime+0
	lds	r17, iotime+1
	std	Y+6, r16
	std	Y+7, r17
	adiw	yh:yl, 8
	andi	yh, high(tesoutlen-1)	; 
	ori	yh, high(tesoutbuf)
	sts	tesoutptr+0, yl
	sts	tesoutptr+1, yh
#endif
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	pop	r17
	pop	r16
	reti
;--------------------------------------------------------------------------
;
;	free() a previously allocated buffer, note that you must not call free
;	with a buffer that has never been allocated or has allready been freed.
;	This will be fatal and there is no way we can check that with the
;	current implementation. 
;	
;	Input:
;			r25:r24	address of the block to be released.
;	Registers:
;			none
;
free:
	cbi	b_RTOS		; Trigger software interrupt
	push	r16		; Save Registers
	push	r17		;; 
	push	xl		;;;
	push	xh
	push	yl
	push	yh
	push	zl
	push	zh
free100:
	sbis	b_RTOS		;;; check ISR has been executed
	rjmp	free100		;;;
	sbi	f_RTOS		;;; acknowledge
;
;
;
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
	movw	r17:r16, X
	or	r16, r17
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
	cp	xl, yl		; Our next buffer above the current
	cpc	xh, yh
	brlo	free010		; Make sure we reach the end
;
;	We arrive here only when Z<Y<X, either Z<Y<X or Z<Y and X=0
;
free030:
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
	ldd	r24, Z+0	; Get length of previous block
	ldd	r25, Z+1
	ldd	r16, Y+0		; Get length of released block
	ldd	r17, Y+1
	add	r24, r16		; Add lengths together
	adc	r25, r17
	std	Z+0, r24	; Store length into combined block
	std	Z+1, r25
	std	Z+2, xl		; End let it point to next block (could be zero)
	std	Z+3, xh
	movw	Y, Z		; Now released block is combined block for next check
;
;	check if released or combined block (Y) is adjacent to the next block (X)
;
free040:
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
	ldd	r24, Y+0	; Get length of released/combined block
	ldd	r25, Y+1
	ld	r16, X+		; Get length of next block
	ld	r17, X+
	add	r24, r16		; Add lengths together
	adc	r25, r17
	std	Y+0, r24	; Store new length of combined block
	std	Y+1, r25
	ld	r16, X+		; Get pointer in next block		
	ld	r17, X+
	std	Y+2, r16		; And save it in pointer of combined block
	std	Y+3, r17
;
;	
;
free050:
	pop	zh
	pop	zl
	pop	yh
	pop	yl
	pop	xh
	pop	xl
	pop	r17
	pop	r16
	reti
