;--------------------------------------------------------------------------
;
;	Close File
;
;	Input
;	
;	Y	file control block
;
;	Verions 2.0
;
;	r25:r24	file control block
WriteFileClose:
	;
	;	If there are bytes not written to the disk do so
	;
ReadFileClose:
	push	yl
	push	yh
	movw	zh:zl, r25:r24
	ldd	yl, Z+fcb_volume+0
	ldd	yh, Z+fcb_volume+1
	ldd	r18, Y+Vol_FileCnt
	dec	r18
	std	Y+Vol_FileCnt, r18
	ldd	yl, Z+fcb_iob+0
	ldd	yh, Z+fcb_iob+1
	ldd	r24, Y+P_address+0
	ldd	r25, Y+P_address+1
	push	zl
	push	zh
	call	free			; IO Buffer
	movw	r25:r24, Y
	call	free			; Parameter block
	pop	r25
	pop	r24
	call	free			; File Control block
	clr	r24			; this is always successfull
	pop	yh
	pop	yl
	ret


