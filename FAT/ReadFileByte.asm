;--------------------------------------------------------------------------
;
;	Read One Byte from open file
;
;	Get next byte from file. 
;
;	-	Return 0x1a (^Z for end-of-file) if already all bytes read
;	-	Update file pointer
;	-	read next sector in cluster if last byte of sector already read
;	-	link to next cluster if all bytes in cluster already read
;
;	Input
;	
;	Y	file control block
;
;	Output
;
;	CS	Error
;	r24	Error Code, most important 0x1a for end-of-file
;
;	CC	Error
;	r24	Byte
;
;	Registers
;	
;	r18, r4, r5, r6, r7
;
;	Version 2.0
;	Input:
;	r25:r24	struct* filecontrolblock
;	
;	01-06-2022 New Return Value
;
;	uint16_t
;
ReadFileByte:
;
;	First check if we already reached end-of-file
;
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	r20, Y+fcb_position+0	; get current posistion
	ldd	r21, Y+fcb_position+1
	ldd	r22, Y+fcb_position+2
	ldd	r23, Y+fcb_position+3	
	ldd	r16, Y+fcb_filesize+0	; compare to file size
	ldd	r17, Y+fcb_filesize+1
	ldd	r18, Y+fcb_filesize+2
	ldd	r19, Y+fcb_filesize+3
	cp	r20, r16
	cpc	r21, r17
	cpc	r22, r18
	cpc	r23, r19
	brlo	ReadFileByte010		; we still have some bytes left
	ldd	r16, Y+fcb_flag
	sbr	r16, (1<<F__EOF) | (1<<F__ERR)
	std	Y+fcb_flag, r16
	clr	r24
	rjmp	ReadFileByteExit
	
ReadFileByte010:
;
;	Next check if there is a byte left in the sector buffer
;
	subi	r20, byte1(-1)
	sbci	r21, byte2(-1)
	sbci	r22, byte3(-1)
	sbci	r23, byte4(-1)
	std	Y+fcb_position+0, r20
	std	Y+fcb_position+1, r21
	std	Y+fcb_position+2, r22
	std	Y+fcb_position+3, r23
	
	ldd	r16, Y+fcb_byteinsec+0	; get offset in sector
	ldd	r17, Y+fcb_byteinsec+1
	ldi	r18, low(512)		; reached end of sector
	ldi	r19, high(512)
	cp	r16, r18
	cpc	r17, r19
	brlo	ReadFileByte030		; no still bytes in sector
;
;	Need a new sector, as ReadFileOpen already has read the first sector
;	we need to increment the sector number first
;
	ldd	zl, Y+fcb_iob+0
	ldd	zh, Y+fcb_iob+1
	ldd	r16, Z+P_sector+0	; increment sector for next in cluster
	ldd	r17, Z+P_sector+1
	ldd	r18, Z+P_sector+2
	ldd	r19, Z+P_sector+3
	subi	r16, byte1(-1)
	sbci	r17, byte2(-1)
	sbci	r18, byte3(-1)
	sbci	r19, byte4(-1)
	std	Z+P_sector+0, r16
	std	Z+P_sector+1, r17
	std	Z+P_sector+2, r18
	std	Z+P_sector+3, r19
	ldd	r16, Y+fcb_sectperclst	; how many sectors did we already read
	ldd	zl, Y+fcb_volume+0
	ldd	zh, Y+fcb_volume+1	; Volume control block
	ldd	r17, Z+Vol_sectperclst	; compare to number of sectors in cluster
	cp	r16, r17
	brlo	ReadFileByte020		; still within current cluster
;
;	Need next cluster
;
	ldd	r22, Y+fcb_volume+0
	ldd	r23, Y+fcb_volume+1	; Volume control block
	ldd	r24, Y+fcb_iob+0
	ldd	r25, Y+fcb_iob+1	; Parameter block
	call	LinkedCluster		; get linked cluster
	ldd	r22, Y+fcb_volume+0
	ldd	r23, Y+fcb_volume+1	; Volume control block
	ldd	r24, Y+fcb_iob+0
	ldd	r25, Y+fcb_iob+1	; Parameter block
	call	Cluster2Sector		; convert cluster to sector
	clr	r16
ReadFileByte020:
	inc	r16
	std	Y+fcb_sectperclst, r16	; initialise number of sectors read
	ldd	r24, Y+fcb_iob+0
	ldd	r25, Y+fcb_iob+1
	call	SD_CARD_READ
	tst	r24
	breq	ReadFileByte025
	ldd	r16, Y+fcb_flag
	sbr	r16, (1<<F__IOE) | (1<<F__ERR)
	std	Y+fcb_flag, r16
	rjmp	ReadFileByteExit
ReadFileByte025:
	std	Y+fcb_byteinsec+0, zero
	std	Y+fcb_byteinsec+1, zero
ReadFileByte030:
	ldd	r24, Y+fcb_byteinsec+0	; get offset in sector
	ldd	r25, Y+fcb_byteinsec+1
	ldd	zl, Y+fcb_iob+0		; get io parameter block
	ldd	zh, Y+fcb_iob+1
	ldd	xl, Z+P_address+0	; get IO buffer address
	ldd	xh, Z+P_address+1
	add	xl, r24			; point to byte in question
	adc	xh, r25
	adiw	r25:r24, 1		; increment offset in sector
	std	Y+fcb_byteinsec+0, r24	; update offset in sector
	std	Y+fcb_byteinsec+1, r25
	ld	r24, X			; get byte
ReadFileByteExit:
	pop 	yh
	pop	yl
	ret	

