;--------------------------------------------------------------------------
;
;	Translate logical block to physical sector using the fragment list
;	of the file entry
;
;	Ver2.0
;
;	Input:
;	r25:r24		Pointer to data structure for file IO the field P_Cluster
;			in the associated IO control block must be set to the LBN
;			(Logical Block Number)
;			
;	Output:
;
;	P_Sector	of the assosiated IO control block is set to the PBN
;			(Physical Sector/Block Number)
;	r24		return code
;	(r25:r24	size)
;
Logical2Physical:
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1		; Get parameter block
	ldd	r16, Z+P_Cluster+0	; Get logical block number
	ldd	r17, Z+P_Cluster+1
	ldd	r18, Z+P_Cluster+2
	ldd	r19, Z+P_Cluster+3
	ldd	zl, Y+fcb_fraglist+0
	ldd	zh, Y+fcb_fraglist+1	; Get first fragment descriptor

Logical2Loop:
	ldd	r20, Z+Fr_Length+0	; get size of current fragment list
	ldd	r21, Z+Fr_Length+1	
	ldd	r22, Z+Fr_Length+2	
	ldd	r23, Z+Fr_Length+3	
	cp	r16, r20
	cpc	r17, r21
	cpc	r18, r22
	cpc	r19, r23
	brlo	Logical2Found		; logical block < size -> found

	sub	r16, r20
	sbc	r17, r21
	sbc	r18, r22
	sbc	r19, r23	

	ldd	r24, Z+Fr_List+0	; Get next fragment descriptor
	ldd	r25, Z+Fr_List+1
	sbiw	r25:r24, 0
	brne	Logical2Loop
	ldi	r24, -1
	rjmp	Logical2Exit
;
Logical2Found:
	ldd	r20, Z+Fr_Start+0	; Add physical sector number of first
	ldd	r21, Z+Fr_Start+1
	ldd	r22, Z+Fr_Start+2
	ldd	r23, Z+Fr_Start+3
	
	add	r16, r20
	adc	r17, r21
	adc	r18, r22
	adc	r19, r23

	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1		; Get parameter block
	std	Z+P_Sector+0, r16	; return physical block number
	std	Z+P_Sector+1, r17
	std	Z+P_Sector+2, r18
	std	Z+P_Sector+3, r19
	clr	r24
Logical2Exit:
	pop	yh
	pop	yl
	ret


