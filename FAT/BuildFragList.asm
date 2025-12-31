;--------------------------------------------------------------------------
;
;	Create a fragment list of a file. The fragmentlist consists of
;	tuples of fragmentsize and fragmentstart.  Each tuple is a 32-bit
;	integer. This is to support direct block IO to disk images without
;	the need to read additional sectors from the device.
;
;	size	the size of this fragments in sectors
;	start	the number of the first sector covered by this fragment
;
;	When we now need to read or write a specific sector of a file we need
;	to find the corresponding entry. For this we compare the sector we 
;	want with the size of the fragment. If it is lower then we found the
;	fragment. Else we subtract the size from the sector which can be looked
;	at as the offset into the next fragment. If the calculated value is
;	less then the size of the next fragment we are done. Else we continue
;	until the number of sector is negative (if a file is 4 sectors long
;	the sectors we can read are numbered 0,1,2,3. When we subtract the
;	legnths of all fragements from the sector to read the result is -1)
;
;	When we found a fragment we just need to add the (remaining) sector
;	offset to the start sector number of this fragment. The results is
;	then the absolute sector on the device.
;
;	Input:
;		r25:r24	Pointer to file control block
;
;	Output:
;		Fragmentlist created
;
;
;	Completioncode:
;		-1	The file has more fragments than we can store in memory
;		0	Created complete fragment list
;
;
; uint8_t BuildFagList(struct* FileControlBlock)
;
BuildFragList:
	push	r11
	push	r12
	push	r13
	push	r14
	push	r15
	push	yl
	push	yh
	movw	r15:r14, r25:r24	; Keep FCB in a save place
	movw	zh:zl, r25:r24		; Copy File Control Block to pointer
	ldd	yl, Z+fcb_Volume+0	; 
	ldd	yh, Z+fcb_Volume+1
	ldd	r11, Y+Vol_sectperclst	;

	movw	r13:r12, yh:yl		; Save Volume Control Block
	ldd	yl, Z+fcb_iob+0
	ldd	yh, Z+fcb_iob+1
	ldd	r16, Z+fcb_Flag	;
	sbr	r16, (1<<F__Contig)	; Assume Continguous File
	std	Z+fcb_Flag, r16
	adiw	zh:zl, fcb_fraglist
BuildFragListNext:
	ldi	r24, low(Fr_Size)	; Get a memory block for one fragment entry
	ldi	r25, high(Fr_Size)
	call	malloc
	sbiw	r25:r24, 0
	brne	BuildFragList010
	movw	r25:r24, r15:r14
	adiw	r25:r24, fcb_fraglist	; Queue Head Address
	rcall	FreeList	
	ldi	r24, -1
	rjmp	BuildFragListExit
	
BuildFragList010:
	std	Z+Fr_List+0, r24	; Copy address to the previous queue head
	std	Z+Fr_List+1, r25
	movw	zh:zl, r25:r24		; New queue head
	std	Z+Fr_List+0, zero	; Current end of chain
	std	Z+Fr_List+1, zero
	std	Z+Fr_Length+0, r11	; initialise packet with a fragment of at
	std	Z+Fr_Length+1, zero	; least one cluster
	std	Z+Fr_Length+2, zero
	std	Z+Fr_Length+3, zero	; initial size of fragment = sectors per cluster

	movw	r23:r22, r13:r12	; Volume Control Block
	movw	r25:r24, yh:yl		; Parameter Block
	push	zl
	push	zh
	rcall	Cluster2Sector		; convert cluster to sector
	pop	zh
	pop	zl
	ldd	r16, Y+P_Sector+0	; And make this the 
	ldd	r17, Y+P_Sector+1
	ldd	r18, Y+P_Sector+2
	ldd	r19, Y+P_Sector+3

	std	Z+Fr_Start+0, r16	; start sector of this fragment.
	std	Z+Fr_Start+1, r17
	std	Z+Fr_Start+2, r18
	std	Z+Fr_Start+3, r19
BuildFragListLoop:
	ldd	r16, Y+P_Cluster+0
	ldd	r17, Y+P_Cluster+1
	ldd	r18, Y+P_Cluster+2	
	ldd	r19, Y+P_Cluster+3	; Save current cluster in the P_Sector

	std	Y+P_Sector+0, r16	;
	std	Y+P_Sector+1, r17	;
	std	Y+P_Sector+2, r18	;
	std	Y+P_Sector+3, r19	; which is currently not used

	movw	r23:r22, r13:r12	; Volume Control Block
	movw	r25:r24, yh:yl		; Parameter Block
	push	zl
	push	zh
	rcall	LinkedCluster		; Get linked cluster
	pop	zh
	pop	zl
	cpi	r24, FAT_EOF
	breq	BuildFragListDone	; No more clusters
	ldd	r16, Y+P_Sector+0	; Get previous cluster
	ldd	r17, Y+P_Sector+1	; 
	ldd	r18, Y+P_Sector+2	; 
	ldd	r19, Y+P_Sector+3	; 

	subi	r16, byte1(-1)
	sbci	r17, byte2(-1)
	sbci	r18, byte3(-1)
	sbci	r19, byte4(-1)		; Increment by one

	ldd	r20, Y+P_Cluster+0
	cp	r20, r16
	ldd	r20, Y+P_Cluster+1
	cpc	r20, r17
	ldd	r20, Y+P_Cluster+2
	cpc	r20, r18
	ldd	r20, Y+P_Cluster+3
	cpc	r20, r19
	breq	BuildFragList020
	movw	r25:r24, Z		; Save Z
	movw	Z, r15:r14		; get FCB
	ldd	r16, Z+fcb_Flag	;
	cbr	r16, (1<<F__Contig)	; File is _not_ continguous
	std	Z+fcb_Flag, r16
	movw	Z, r24:r25		; Restore Z
	rjmp	BuildFragListNext	; need new fragement entry
;
BuildFragList020:
	ldd	r16, Z+Fr_Length+0	; next cluster is adjacent, i.e. it belongs
	ldd	r17, Z+Fr_Length+1	; to this fragment, so we just
	ldd	r18, Z+Fr_Length+2	; 
	ldd	r19, Z+Fr_Length+3	; 
	add	r16, r11		; add sectors per cluster
	adc	r17, zero		; to this fragmentsize
	adc	r18, zero
	adc	r19, zero
	std	Z+Fr_Length+0, r16
	std	Z+Fr_Length+1, r17
	std	Z+Fr_Length+2, r18
	std	Z+Fr_Length+3, r19	; save
	rjmp	BuildFragListLoop	; check next clusters
;
BuildFragListDone:
	clr	r24
BuildFragListExit:
	pop	yh
	pop	yl
	pop	r15
	pop	r14
	pop	r13
	pop	r12
	pop	r11
	ret

