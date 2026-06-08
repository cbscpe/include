;--------------------------------------------------------------------------
;
;	Translate logical block to physical sector using the fragment list
;	of the file entry
;
;	Ver2.0b
;
;	This replaces Ver2.0. In addition to translating the LBN into PBN
;	it also returns the number of sectors left in the fragment that could
;	be read consecutively.
;
;	Input:
;	r25:r24		Pointer to data structure for file IO control block
;	P_Cluster	The field P_Cluster of the associated IO control block 
;			must be set to the LBN(Logical Block Number)
;			
;	Output:
;
;	P_Sector	of the assosiated IO control block is set to the PBN
;			(Physical Sector/Block Number)
;	P_MaxSector	Number of contiguous sectors that can be accessed
;
;	r24		return code, 0=Success, -1=
;
;
;	This is replacement candidate for the existing Logical2Physical routine
;	and requires that you check the return code. 
;	
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
	movw	zh:zl, r25:r24
	sbiw	r25:r24, 0
	brne	Logical2Loop	
	ldi	r24, -1
	rjmp	Logical2Exit		; if r25:r24 == 0 then return illegal LBN
;
Logical2Found:
;
;	r19:r18:r17:r16 (the remaining sector) is within this fragment
;
	ldd	r20, Z+Fr_Start+0	; Add physical sector number of first
	ldd	r21, Z+Fr_Start+1
	ldd	r22, Z+Fr_Start+2
	ldd	r23, Z+Fr_Start+3
	
	add	r20, r16
	adc	r21, r17
	adc	r22, r18
	adc	r23, r19
	
	movw	r25:r24, zh:zl		; Save Fragment Entry Pointer
	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1		; Get parameter block
	std	Z+P_Sector+0, r20	; return physical block number
	std	Z+P_Sector+1, r21
	std	Z+P_Sector+2, r22
	std	Z+P_Sector+3, r23

	movw	zh:zl, r25:r24		; Restore Fragment Entry Pointer
	ldd	r20, Z+Fr_Length+0	; get size of current fragment list
	ldd	r21, Z+Fr_Length+1	
	ldd	r22, Z+Fr_Length+2	
	ldd	r23, Z+Fr_Length+3	

	sub	r20, r16		; Calculate the number of blocks left
	sbc	r21, r17		; in fragment, this will be the maximum
	sbc	r22, r18		; number of sectors left in the fragment
	sbc	r23, r19		; that can be read before having to call
					; Logical2Physical again

	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1		; Get parameter block
	std	Z+P_MaxSector+0, r20	; return physical block number
	std	Z+P_MaxSector+1, r21
	std	Z+P_MaxSector+2, r22
	std	Z+P_MaxSector+3, r23
	clr	r24
Logical2Exit:
	pop	yh
	pop	yl
	ret


