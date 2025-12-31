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
FreeListNext:
	ldd	yl, Z+0			; Get next packet address
	ldd	yh, Z+1
	movw	r25:r24, Y		; 
	ldd	zl, Y+0			; Get linked packet address
	ldd	zh, Y+1
	call	free			; Free this packet
;	cp	zl, zero		; Check next packet address
;	cpc	zh, zero
	sbiw	zh:zl, 0
	brne	FreeListNext		; there is still another one
;
	pop	zh
	pop	zl
	std	Z+0, zero		; Clear the list head
	std	Z+1, zero
	pop	yh
	pop	yl
	ret


