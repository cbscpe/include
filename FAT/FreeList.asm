;--------------------------------------------------------------------------
;
;	This routine disposes a list of packets from a given point. This can
;	be either the queue list head or any packet address, provided the 
;	pointer to the next packet is stored in the first two bytes.
;
;	Input:
;		r25:r24		Listheader
;
;	Output:
;		Listhead is zeroized queued packets are freed
;
;	Registers:
;		none
;	
FreeList:
	push	yl
	push	yh
	movw	zh:zl, r25:r24
	push	zl
	push	zh
;	
	ldd	yl, Z+0			; Get next packet address
	ldd	yh, Z+1
FreeListNext:
	ldd	zl, Y+0			; Remember Next
	ldd	zh, Y+1
;
;	
;	
;	sbiw	yh:yl, 2
;	ld	r24, Y+
;	ld	r25, Y+
;	sts	pprint+0, r24
;	sts	pprint+1, r25
;	sts	pprint+2, yl
;	sts	pprint+3, yh
;	call	print
;	.db	CR, LF, "Free 0x", 0x81, 0x80, " bytes at 0x", 0x83, 0x82, 0
;
;
;
	movw	r25:r24, yh:yl
	call	free			; Free this packet
	movw	yh:yl, zh:zl
	sbiw	yh:yl, 0
	brne	FreeListNext		; there is still another one
;
	pop	zh
	pop	zl
	std	Z+0, zero		; Clear the list head
	std	Z+1, zero
	pop	yh
	pop	yl
	ret


