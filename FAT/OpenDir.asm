;--------------------------------------------------------------------------
;
;	Open Directory
;
;	Opens the current directory, it will prepare all pointers and 
;	counters to start reading directory entries. 
;	P_Cluster of Vol_diriob must be set to the first cluster of the
;	directory. In case you want to open the ROOT directory P_Cluster must
;	be set to zero. 
;
; uint8_t OpenDir
;
OpenDir:;(struct* VolumeControlBlock);
	push	yl
	push	yh
	movw	yh:yl, r25:r24
	ldi	r24, FAT_OFL
	ldd	r20, Y+Vol_Status
	sbrs	r20, Vol__MBR
	rjmp	OpenDirExit		; MBR not ok -> error
	sbrs	r20, Vol__VBR                                       
	rjmp	OpenDirExit		; VBR not ok -> error	
	
	ldd	zl, Y+Vol_diriob+0
	ldd	zh, Y+Vol_diriob+1
	
	ldd	r16, Z+P_Cluster+0	; Test if ROOT directory requested
	ldd	r17, Z+P_Cluster+1
	ldd	r18, Z+P_Cluster+2
	ldd	r19, Z+P_Cluster+3
	
	subi	r16, 0
	sbci	r17, 0
	sbci	r18, 0
	sbci	r19, 0
	brne	OpenDirCluster		; Directory is a linked list of clusters

	ldd	r16, Y+Vol_rootdir+0	; Get the start of the root directory
	ldd	r17, Y+Vol_rootdir+1
	ldd	r18, Y+Vol_rootdir+2
	ldd	r19, Y+Vol_rootdir+3

	sbrs	r20, Vol__FAT32
	rjmp	OpenRootDir		; Special Case FAT16
	
	std	Z+P_Cluster+0, r16	; In case of FAT32 this is also just a linked
	std	Z+P_Cluster+1, r17	; list of clusters
	std	Z+P_Cluster+2, r18
	std	Z+P_Cluster+3, r19
OpenDirCluster:
	movw	r23:r22, yh:yl		; Volume Control Block
	movw	r25:r24, zh:zl		; Parameter Block
	rcall	Cluster2Sector		; Convert Cluster to Sector
	ldd	zl, Y+Vol_diriob+0	; Restore Parameter Block Address
	ldd	zh, Y+Vol_diriob+1
	ldd	r18, Y+Vol_Status
	sbr	r18, 1<<Vol__Linked
	std	Y+Vol_Status, r18	; Directory is a linked list of clusters
	ldd	r18, Y+Vol_sectperclst	; Number of Sectors in Cluster
	rjmp	OpenDirAll

OpenRootDir:
	std	Z+P_Sector+0, r16	; In case of FAT16 the root directory is just
	std	Z+P_Sector+1, r17	; a contiguous block of sectors
	std	Z+P_Sector+2, r18
	std	Z+P_Sector+3, r19
	ldd	r18, Y+Vol_Status
	cbr	r18, 1<<Vol__Linked
	std	Y+Vol_Status, r18	; Directory is just a block of sectors
	ldd	r18, Y+Vol_dirsectors	; Number of Sectors in Root Directory	
OpenDirAll:	
	std	Z+P_NumSect, r18	; Number of sectors
	ldi	r18, -1
	std	Y+Vol_DirCount, r18	; Directory entries processed -1 
	ldd	r18, Z+P_Address+0
	ldd	r19, Z+P_Address+1
	std	Y+Vol_DirNxtPtr+0, r18	; Set address of next directory entry to check
	std	Y+Vol_DirNxtPtr+1, r19
	movw	r25:r24, zh:zl
	call	SD_CARD_READ		; Get first sector of directory
OpenDirExit:
	pop	yh
	pop	yl
	ret

