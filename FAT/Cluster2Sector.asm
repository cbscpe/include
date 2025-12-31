;==========================================================================
;
;	Cluster / Sector Routines
;
;--------------------------------------------------------------------------
;
;	Translate Cluster to first sector number in cluster using the formula
;
;		Sector = (Cluster - 2) * SectorsPerCluster + FirstDataSector
;
;	Input:
;		r25:r24	Pointer to datastructure with P_Cluster set
;		r23:r22	Pointer to Volume Control Block
;	Output:
;		P_Sector set to first sector in cluster
;
;
Cluster2Sector:;(struct* IOParameterBlock, struct* VolumeControlBlock)
	push	r0
	push	r1			; mul
	push	yl
	push	yh
	movw	yh:yl, r25:r24		; Parameter Block
	movw	zh:zl, r23:r22		; Volume Control Block
	
	ldd	r16, Y+P_Cluster+0
	ldd	r17, Y+P_Cluster+1
	ldd	r18, Y+P_Cluster+2
	ldd	r19, Y+P_Cluster+3

	subi	r16, byte1(2)		; The first cluster is 2!
	sbci	r17, byte2(2)
	sbci	r18, byte3(2)
	sbci	r19, byte4(2)
	
	ldd	r20, Z+Vol_datastart+0	; Data Start Sector
	ldd	r21, Z+Vol_datastart+1
	ldd	r22, Z+Vol_datastart+2
	ldd	r23, Z+Vol_datastart+3
	ldd	r24, Z+Vol_sectperclst
	clr	r25			; in case r1 is the zero constant
	
	
	mul	r16, r24		; Cluster-2 bits0:7
	add	r20, r0
	adc	r21, r1
	adc	r22, r25 ; zero
	adc	r23, r25 ; zero
	mul	r17, r24		; Cluster-2 bits8:15
	add	r21, r0
	adc	r22, r1
	adc	r23, r25 ; zero
	mul	r18, r24		; Cluster-2 bits16:23
	add	r22, r0
	adc	r23, r1
	mul	r19, r24		; Cluster-2 bits24:31
	add	r23, r0
	
	std	Y+P_Sector+0, r20
	std	Y+P_Sector+1, r21
	std	Y+P_Sector+2, r22
	std	Y+P_Sector+3, r23
	pop	yh
	pop	yl
	pop	r1
	pop	r0
	ret

