

;--------------------------------------------------------------------------
;
;	Read Directory Entry and returns a pointer either to the next active
;	or free directory entry if one exists. If no free directory entry
;	exists the pointer is set to zero. To read a directory first call
;	OpenDir with the P_Cluster set to the first cluster of the directory
;	file (or 0 in case you want to read the root directory). OpenDir and
;	ReadDir automatically handle the special case of FAT16 root directory.
;
;	For vfat long file names ReadDir will compose the long file name
;	into the global LongFileN buffer.
;
;	ReadDir will return the pointer to the 32-byte directory that has
;	the file information (Date, Time, Short File Name, Start Cluster, etc.)
;	in Vol_DirPointer 
;
;	Input:
;	r25:r24		Volume Control Block
;
; uint8_t ReadDir
;
ReadDir:;(struct* VolumeControlBlock);
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
;-	rcall	debugReadDir;+++
	ldd	r18, Y+Vol_Status
	cbr	r18, 1<<Vol__Long
	std	Y+Vol_Status, r18	; No Long File Name so far
ReadDirEntry:
;-	rcall	debugReadDirEntry;++++
	ldd	r18, Y+Vol_DirCount	; Get number of entries already processed
	inc	r18			; Another entry processed
	std	Y+Vol_DirCount, r18
	cpi	r18, (512/32)		; 
	brne	ReadDirThis
;ReadNxtDir:				; We require the next sector of the direcotry
;-	rcall	debugReadNxtDir;++++
	ldd	r18, Z+P_NumSect	; Decrement sectors to read
	dec	r18			; done in directory
	std	Z+P_NumSect, r18	; 
	brne	ReadNxtDirSect		; Just read the next sector (P_Sector++)
	ldd	r18, Y+Vol_Status	; Check directory type
	sbrs	r18, Vol__Linked	; Linked list of clusters (normal file)
	rjmp	ReadNxtDirEnd		; In case of FAT16 root directory no more sectors
;
;	Either a normal directory or the FAT32 root directory is being processed which
;	are built like any file as a list of linked clusters. We reach here when we have
;	processed all sectors in the current cluster so we need to find the next cluster.
;
	movw	r25:r24, zh:zl
	movw	r23:r22, yh:yl
	rcall	LinkedCluster		; Follow Cluster List
	tst	r24
	brne	ReadNxtDirEnd
	ldd	r24, Y+Vol_diriob+0
	ldd	r25, Y+Vol_diriob+1	; Restore IO Parameter Block Pointer
	movw	r23:r22, yh:yl
	rcall	Cluster2Sector
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1	; Restore IO Parameter Block Pointer
	ldd	r18, Y+Vol_sectperclst	; Re-initialise number of 
	std	Z+P_NumSect, r18	; sectors in cluster.
;-	rcall	debugReadNXtDir2;++++
	rjmp	ReadNxtReadSect
;
;	Read next directory sector of the current cluster or FAT16 root directory
;
ReadNxtDirSect:
	ldd	r16, Z+P_Sector+0
	ldd	r17, Z+P_Sector+1
	ldd	r18, Z+P_Sector+2
	ldd	r19, Z+P_Sector+3

	subi	r16, byte1(-1)
	sbci	r17, byte2(-1)
	sbci	r18, byte3(-1)
	sbci	r19, byte4(-1)

	std	Z+P_Sector+0, r16
	std	Z+P_Sector+1, r17
	std	Z+P_Sector+2, r18
	std	Z+P_Sector+3, r19
ReadNxtReadSect:
;-	rcall	debugReadNxtDirSect;++++
	ldi	r18, -1
	std	Y+Vol_DirCount, r18	; No directory entries in sector processed
	ldd	r16, Z+P_Address+0
	ldd	r17, Z+P_Address+1
	std	Y+Vol_DirNxtPtr+0, r16
	std	Y+Vol_DirNxtPtr+1, r17
	movw	r25:r24, zh:zl
	call	SD_CARD_READ
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
	tst	r24
	breq	ReadDirEntry		; Re-enter
ReadNxtDirEnd:
	std	Y+Vol_DirPointer+0, zero	
	std	Y+Vol_DirPointer+1, zero
	rjmp	ReadNxtDirExit	

ReadDirThis:
	ldd	zl, Y+Vol_DirNxtPtr+0
	ldd	zh, Y+Vol_DirNxtPtr+1	; Get pointer to next entry
	std	Y+Vol_DirPointer+0, zl	; save current pointer as directory entry
	std	Y+Vol_DirPointer+1, zh	; 
	ldi	r24, FAT_FDE		; Assume Free Directory Entry
	ldd	r18, Z+D_Name		; Get first character of Name
	tst	r18			; Check if this is the end of the directory
	breq	ReadNxtDirExit		; if yes return the pointer to the free entry
	cpi	r18, 0xe5
	breq	ReadDirNext		; This is a deleted entry, skip it
	ldd	r18, Z+D_Attr		; is it part of a long filename
	cpi	r18, A_Long		; Attribute for Long File Name
	breq	ReadDirLong
	adiw	zh:zl, 32		; Next Entry Address
	std	Y+Vol_DirNxtPtr+0, zl	; New place for this pointer
	std	Y+Vol_DirNxtPtr+1, zh
	clr	r24			; Success

ReadNxtDirExit:
	pop	yh
	pop	yl
	ret

ReadDirNext:
	adiw	zh:zl, 32		; Next Entry Address
	std	Y+Vol_DirNxtPtr+0, zl	; Save for next entry to this routine
	std	Y+Vol_DirNxtPtr+1, zh
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
	rjmp	ReadDirEntry
;
;	We found an entry with the attributes indicating a long file name
;
;	Long file names are stored in blocks of 13 characters. The last part of the
;	filename is stored first. Each block takes one directory entry. For long file
;	name entries the attribute is set to 0x0F and the first byte of the name
;	consists of the sequence number (bits 0..4) and allocation status (bit 6).
;	Bit 6 of the last block is set and as the blocks store the filename from then
;	end to the beginning bit 6 indicates the last block of a file name and at the
;	same time the highest sequence number
;
ReadDirLong:				; Process a long filename entry
	ldd	r18, Y+Vol_Status
	sbrc	r18, Vol__Long		; Are we already processing long file names
	rjmp	ReadDirLongCont		; If set then continue with long filename
	sbr	r18, 1<<Vol__Long	; We start processing of long filenames
	std	Y+Vol_Status, r18
	ldd	r18, Z+D_Name		; Get the sequence number and allocation status
	sbrs	r18, 6			; We expect this to be the last entry
	rjmp	ReadDirNext		; Something is wrong with directory, skip it
	clr	r18
	ldi	xl, low(LongFileN)
	ldi	xh, high(LongFileN)
ReadDirLongClr:
	st	X+, zero
	inc	r18
	brne	ReadDirLongClr		; Initialise long filename buffer with 0x00
	rjmp	ReadDirCopy
ReadDirLongCont:
	ldd	r18, Z+D_Name		; We are already processing long file names
	sbrc	r18, 6			; and therefore the allocation status must be 0
	rjmp	ReadDirNext		; If "Last" flag set this is an error, skip it
ReadDirCopy:
;
;	Copy the characters from a long filename directory entry to the long
;	filename buffer. Long filenames are split into directory entires each
;	with up to 13 double-byte characters. The first byte if the filename
;	has the index of the part. So we just need to multiply the index minus
;	one with 13 and copy the 13 characters. Note we assume it is all
;	ASCII, that is the highbyte of each double-byte character is 0. We do
;	not even check as this would also require that we are able to support
;	this but we are not for the moment. 
;
	ldd	r18, Z+D_Name		; get first byte of filename which 
	andi	r18, 0x1F		; contains the index, isolate the index
	dec	r18			; Sequence - 1
	clr	r19
ReadDirCopy010:
	dec	r18
	brmi	ReadDirCopy020
	subi	r19, -13
	rjmp	ReadDirCopy010
ReadDirCopy020:	
	ldi	xl, low(LongFileN)
	ldi	xh, high(LongFileN)
	add	xl, r19
	adc	xh, zero
;-	rcall	debugReadDirCopy;++++
	ldd	r18, Z+D_Name+1		; copy the 13 locations, note that the
	st	X+, r18			; string in the extension is 0x0000 terminated
	ldd	r18, Z+D_Name+3		; we assume only ASCII double characeters
	st	X+, r18
	ldd	r18, Z+D_Name+5
	st	X+, r18
	ldd	r18, Z+D_Name+7
	st	X+, r18
	ldd	r18, Z+D_Name+9
	st	X+, r18
	ldd	r18, Z+D_Name+14
	st	X+, r18
	ldd	r18, Z+D_Name+16
	st	X+, r18
	ldd	r18, Z+D_Name+18
	st	X+, r18
	ldd	r18, Z+D_Name+20
	st	X+, r18
	ldd	r18, Z+D_Name+22
	st	X+, r18
	ldd	r18, Z+D_Name+24
	st	X+, r18
	ldd	r18, Z+D_Name+28
	st	X+, r18
	ldd	r18, Z+D_Name+30
	st	X+, r18
	rjmp	ReadDirNext

debugReadDir:
	ldd	r21, Z+P_NumSect
	sts	pprint+0, r21
	call	print
	.db	CR, LF
		;----+----1----+----2----+----3
	.db	"ReadDir P_NumSect.......... 0x", 0x80, CR, LF, 0
	ret
	
debugReadDirEntry:
	ldd	r21, Y+Vol_DirCount
	sts	pprint+0, r21
	call	print
		;----+----1----+----2----+----3
	.db	"ReadDirEntry Vol_DirCount.. 0x", 0x80, CR, LF, 0
	ret

debugReadNxtDir:
	ldd	r21, Z+P_NumSect
	sts	pprint+0, r21
	sts	pprint+2, zl
	sts	pprint+3, zh
	call	print
		;----+----1----+----2----+----3
	.db	"ReadNxtDir IOB............. 0x", 0x83, 0x82, CR, LF
	.db	"ReadNxtDir P_NumSect......  0x", 0x80, CR, LF, 0
	ret

debugOpenDirAll:
	ldd	r21, Z+P_Sector+0
	sts	pprint+0, r21
	ldd	r21, Z+P_Sector+1
	sts	pprint+1, r21
	ldd	r21, Z+P_Sector+2
	sts	pprint+2, r21
	ldd	r21, Z+P_Sector+3
	sts	pprint+3, r21
	ldd	r21, Z+P_NumSect
	sts	pprint+4, r21
	call	print
		;----+----1----+----2----+----3
	.db	"OpenDirAll P_Sector........ 0x", 0x83, 0x82, 0x81, 0x80, CR, LF
	.db	"OpenDirAll P_NumSect......  0x", 0x84, CR, LF, 0
	ret
	
debugReadNxtDirSect:
	ldd	r21, Z+P_Sector+0
	sts	pprint+0, r21
	ldd	r21, Z+P_Sector+1
	sts	pprint+1, r21
	ldd	r21, Z+P_Sector+2
	sts	pprint+2, r21
	ldd	r21, Z+P_Sector+3
	sts	pprint+3, r21
	call	print
		;----+----1----+----2----+----3
	.db	"ReadNxtDirSect P_Sector.... 0x", 0x83, 0x82, 0x81, 0x80, CR, LF, 0, 0
	ret

debugReadNXtDir2:
	ldd	r21, Z+P_Sector+0
	sts	pprint+0, r21
	ldd	r21, Z+P_Sector+1
	sts	pprint+1, r21
	ldd	r21, Z+P_Sector+2
	sts	pprint+2, r21
	ldd	r21, Z+P_Sector+3
	sts	pprint+3, r21
	call	print
		;----+----1----+----2----+----3
	.db	"Cluster2Sector P_Sector.... 0x", 0x83, 0x82, 0x81, 0x80, CR, LF, 0, 0
	ret

debugReadDirCopy:
	sts	pprint+0, r19
	call	print
		;----+----1----+----2----+----3
	.db	"ReadDirCopy Name Offset...  0x", 0x80, CR, LF, 0
	ret